provider "template" {
  version = "~> 2.1"
}

locals {
  dns_name       = lower(replace(var.name, " ", "-"))
  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${local.dns_name}.terraform"
  security_group_ids = concat(
    var.exposed_security_group_ids,
    [aws_security_group.docker.id],
  )
  daemon_security_group_ids = concat(
    var.exposed_security_group_ids,
    [aws_security_group.docker.id, aws_security_group.daemon.id],
  )

  instance_type_manager = coalesce(var.instance_type_manager, var.instance_type)
  instance_type_worker  = coalesce(var.instance_type_worker, var.instance_type)
}

data "aws_region" "current" {}

data "aws_availability_zones" "azs" {
}

resource "aws_subnet" "managers" {
  count  = length(data.aws_availability_zones.azs.names)
  vpc_id = var.vpc_id
  cidr_block = cidrsubnet(
    data.aws_vpc.main.cidr_block,
    8,
    var.manager_subnet_segment_start + count.index,
  )
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name} managers ${data.aws_availability_zones.azs.names[count.index]}"
  }

  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

resource "aws_subnet" "workers" {
  count  = length(data.aws_availability_zones.azs.names)
  vpc_id = var.vpc_id
  cidr_block = cidrsubnet(
    data.aws_vpc.main.cidr_block,
    8,
    var.worker_subnet_segment_start + count.index,
  )
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name} workers ${data.aws_availability_zones.azs.names[count.index]}"
  }

  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_ami" "base_ami" {
  most_recent = true
  name_regex  = "^amzn2-ami-hvm-.*-x86_64-ebs"
  owners      = ["amazon", "self"]
}

resource "aws_s3_bucket" "terraform" {
  bucket        = local.s3_bucket_name
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    transition {
      days          = 30
      storage_class = "ONEZONE_IA"
    }
  }

  tags = {
    Name = "${var.name} Swarm"
  }
}

resource "aws_security_group" "docker" {
  name        = "docker"
  description = "Docker Swarm ports"
  vpc_id      = var.vpc_id

  ingress {
    description = "Docker swarm management"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Docker container network discovery"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Docker container network discovery"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description = "Docker overlay network"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.name} Docker"
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }
}

resource "aws_security_group" "daemon" {
  name        = "docker-daemon"
  description = "Docker Daemon port"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2376
    to_port     = 2376
    protocol    = "tcp"
    cidr_blocks = [var.daemon_cidr_block]
  }

  tags = {
    Name = "${var.name} Docker Daemon"
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3-access-role-policy" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.terraform.arn,
      "${aws_s3_bucket.terraform.arn}/*",
    ]
  }
  # SimpleDB is not available in all regions
  #
  # statement {
  #   actions = [
  #     "sdb:GetAttributes",
  #     "sdb:BatchDeleteAttributes",
  #     "sdb:PutAttributes",
  #     "sdb:DeleteAttributes",
  #     "sdb:Select",
  #     "sdb:DomainMetadata",
  #     "sdb:BatchPutAttributes",
  #   ]

  #   resources = [
  #     "*",
  #   ]
  # }
}

# SimpleDB is not available in all regions
#
# resource "aws_simpledb_domain" "db" {
#   name = "${local.dns_name}.tf"
# }

resource "aws_iam_policy" "s3-access-role-policy" {
  name   = "${local.dns_name}-ec2-policy"
  policy = data.aws_iam_policy_document.s3-access-role-policy.json
}

resource "aws_iam_role" "ec2" {
  name               = "${local.dns_name}-ec2"
  description        = "Allows reading of infrastructure secrets"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "s3-access-role-policy" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3-access-role-policy.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.dns_name}-ec2"
  role = aws_iam_role.ec2.name
}

resource "aws_s3_bucket_public_access_block" "terraform" {
  depends_on = [
    aws_s3_bucket.terraform
  ]
  bucket = aws_s3_bucket.terraform.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
