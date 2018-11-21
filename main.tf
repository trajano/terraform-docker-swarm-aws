locals {
  dns_name           = "${lower(replace(var.name, " ", "-"))}"
  s3_bucket_name     = "${var.s3_bucket_name != "" ? var.s3_bucket_name : "${local.dns_name}.terraform"}"
  security_group_ids = "${concat(var.exposed_security_group_ids, list(aws_security_group.docker.id))}"
}

data "aws_availability_zones" "azs" {}

resource "aws_subnet" "managers" {
  count                   = "${length(data.aws_availability_zones.azs.names)}"
  vpc_id                  = "${var.vpc_id}"
  cidr_block              = "${cidrsubnet(data.aws_vpc.main.cidr_block, 8, var.manager_subnet_segment_start + count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.name} managers ${data.aws_availability_zones.azs.names[count.index]}"
  }

  availability_zone = "${data.aws_availability_zones.azs.names[count.index]}"
}

resource "aws_subnet" "workers" {
  count                   = "${length(data.aws_availability_zones.azs.names)}"
  vpc_id                  = "${var.vpc_id}"
  cidr_block              = "${cidrsubnet(data.aws_vpc.main.cidr_block, 8, var.worker_subnet_segment_start + count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.name} workers ${data.aws_availability_zones.azs.names[count.index]}"
  }

  availability_zone = "${data.aws_availability_zones.azs.names[count.index]}"
}

data "aws_vpc" "main" {
  # id = "${local.vpc_id}"
  id = "${var.vpc_id}"
}

data "aws_ami" "base_ami" {
  most_recent = true
  name_regex  = "^amzn2-ami-hvm-.*-x86_64-ebs"
  owners      = ["amazon", "self"]
}

resource "aws_s3_bucket" "terraform" {
  bucket        = "${local.s3_bucket_name}"
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    transition {
      days          = 30
      storage_class = "ONEZONE_IA"
    }
  }

  tags {
    Name = "${var.name} Swarm"
  }
}

resource "aws_security_group" "docker" {
  name        = "docker"
  description = "Docker Swarm ports"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.main.cidr_block}"]
  }

  ingress {
    from_port   = 2376
    to_port     = 2376
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.main.cidr_block}"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.main.cidr_block}"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["${data.aws_vpc.main.cidr_block}"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["${data.aws_vpc.main.cidr_block}"]
  }

  tags {
    Name = "${var.name} Docker"
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
      "${aws_s3_bucket.terraform.arn}",
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
  policy = "${data.aws_iam_policy_document.s3-access-role-policy.json}"
}

resource "aws_iam_role" "ec2" {
  name               = "${local.dns_name}-ec2"
  description        = "Allows reading of infrastructure secrets"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}

resource "aws_iam_role_policy_attachment" "s3-access-role-policy" {
  role       = "${aws_iam_role.ec2.name}"
  policy_arn = "${aws_iam_policy.s3-access-role-policy.arn}"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.dns_name}-ec2"
  role = "${aws_iam_role.ec2.name}"
}

data "template_file" "init_manager" {
  count    = "${var.managers}"
  template = "${file("${path.module}/init_manager.py")}"

  vars {
    s3_bucket      = "${aws_s3_bucket.terraform.bucket}"
    instance_index = "${count.index}"
  }
}

data "template_cloudinit_config" "managers" {
  count         = "${var.managers}"
  gzip          = "true"
  base64_encode = "true"

  part {
    content = "${file("${path.module}/common.cloud-config")}"
  }

  part {
    filename     = "extra.sh"
    content      = "${var.cloud_config_extra}"
    content_type = "text/cloud-config"
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }

  part {
    filename     = "init_manager.py"
    content      = "${data.template_file.init_manager.*.rendered[count.index]}"
    content_type = "text/x-shellscript"
  }
}

data "template_file" "init_worker" {
  count    = "${var.workers}"
  template = "${file("${path.module}/init_worker.py")}"

  vars {
    s3_bucket      = "${aws_s3_bucket.terraform.bucket}"
    instance_index = "${count.index}"
  }
}

data "template_cloudinit_config" "workers" {
  count         = "${var.workers}"
  gzip          = "true"
  base64_encode = "true"

  part {
    content = "${file("${path.module}/common.cloud-config")}"
  }

  part {
    filename     = "extra.sh"
    content_type = "text/cloud-config"
    content      = "${var.cloud_config_extra}"
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }

  part {
    filename     = "init_worker.py"
    content      = "${data.template_file.init_worker.*.rendered[count.index]}"
    content_type = "text/x-shellscript"
  }
}

resource "aws_instance" "managers" {
  count                  = "${data.template_cloudinit_config.managers.count}"
  ami                    = "${data.aws_ami.base_ami.id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${aws_subnet.managers.*.id[count.index % length(data.aws_availability_zones.azs.*.names)]}"
  private_ip             = "${cidrhost(aws_subnet.managers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}"
  vpc_security_group_ids = ["${local.security_group_ids}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ec2.name}"
  user_data_base64       = "${data.template_cloudinit_config.managers.*.rendered[count.index]}"

  tags {
    Name = "${var.name} manager ${count.index}"
  }

  root_block_device {
    volume_size = "${var.volume_size}"
  }

  lifecycle {
    ignore_changes = [
      "ami",
      "user_data_base64",
    ]
  }

  credit_specification {
    cpu_credits = "standard"
  }
}

resource "aws_instance" "workers" {
  count                  = "${data.template_cloudinit_config.workers.count}"
  ami                    = "${data.aws_ami.base_ami.id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${aws_subnet.workers.*.id[count.index % length(data.aws_availability_zones.azs.*.names)]}"
  private_ip             = "${cidrhost(aws_subnet.workers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}"
  vpc_security_group_ids = ["${local.security_group_ids}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ec2.name}"
  user_data_base64       = "${base64gzip(data.template_cloudinit_config.workers.*.rendered[count.index])}"
  key_name               = "${var.key_name}"

  tags {
    Name = "${var.name} worker ${count.index}"
  }

  root_block_device {
    volume_size = "${var.volume_size}"
  }

  lifecycle {
    ignore_changes = [
      "ami",
      "user_data_base64",
    ]
  }

  credit_specification {
    cpu_credits = "standard"
  }
}
