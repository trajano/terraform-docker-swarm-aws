provider "null" {
  version = "~> 1.0"
}

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

resource "aws_iam_role" "ec2" {
  name               = "${local.dns_name}-ec2"
  description        = "Allows reading of infrastructure secrets"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}

resource "aws_iam_role_policy_attachment" "AmazonS3FullAccess" {
  role       = "${aws_iam_role.ec2.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.dns_name}-ec2"
  role = "${aws_iam_role.ec2.name}"
}

data "template_file" "manager_cloud_config" {
  count    = "${var.managers}"
  template = "${file("${path.module}/manager.cloud-config")}"

  vars {
    s3_bucket      = "${aws_s3_bucket.terraform.bucket}"
    instance_index = "${count.index}"
    manager0_ip    = "${cidrhost(aws_subnet.managers.*.cidr_block[0], 10)}"
    extra          = "${var.cloud_config_extra}"
  }
}

data "template_file" "worker_cloud_config" {
  count    = "${var.workers}"
  template = "${file("${path.module}/worker.cloud-config")}"

  vars {
    s3_bucket      = "${aws_s3_bucket.terraform.bucket}"
    instance_index = "${count.index}"
    manager0_ip    = "${cidrhost(aws_subnet.managers.*.cidr_block[0], 10)}"
    extra          = "${var.cloud_config_extra}"
  }
}

resource "aws_instance" "managers" {
  count                  = "${data.template_file.manager_cloud_config.count}"
  ami                    = "${data.aws_ami.base_ami.id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${aws_subnet.managers.*.id[count.index % length(data.aws_availability_zones.azs.*.names)]}"
  private_ip             = "${cidrhost(aws_subnet.managers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}"
  vpc_security_group_ids = ["${local.security_group_ids}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ec2.name}"

  user_data_base64 = "${base64gzip(data.template_file.manager_cloud_config.*.rendered[count.index])}"

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
  count                  = "${data.template_file.worker_cloud_config.count}"
  ami                    = "${data.aws_ami.base_ami.id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${aws_subnet.workers.*.id[count.index % length(data.aws_availability_zones.azs.*.names)]}"
  private_ip             = "${cidrhost(aws_subnet.workers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}"
  vpc_security_group_ids = ["${local.security_group_ids}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ec2.name}"
  user_data_base64       = "${base64gzip(data.template_file.worker_cloud_config.*.rendered[count.index])}"

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
