locals {
  dns_name = lower(replace(var.name, " ", "-"))
  security_group_ids = concat(
    var.exposed_security_group_ids,
    var.additional_security_group_ids,
    [
      aws_security_group.docker.id
    ],
  )
  daemon_security_group_ids = concat(
    var.exposed_security_group_ids,
    var.additional_security_group_ids,
    [
      aws_security_group.docker.id
    ],
    aws_security_group.daemon.*.id,
    aws_security_group.daemon_ssh.*.id,
  )

  instance_type_manager           = coalesce(var.instance_type_manager, var.instance_type)
  instance_type_worker            = coalesce(var.instance_type_worker, var.instance_type)
  burstable_instance_type_manager = regex("^t\\d\\..*", local.instance_type_manager) != ""
  burstable_instance_type_worker  = regex("^t\\d\\..*", local.instance_type_worker) != ""
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
  owners = [
    "amazon",
    "self",
  ]
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
    cidr_blocks = [
      data.aws_vpc.main.cidr_block,
    ]
  }

  ingress {
    description = "Docker container network discovery"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = [
      data.aws_vpc.main.cidr_block,
    ]
  }

  ingress {
    description = "Docker container network discovery"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = [
      data.aws_vpc.main.cidr_block,
    ]
  }

  ingress {
    description = "Docker overlay network"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [
      data.aws_vpc.main.cidr_block,
    ]
  }

  egress {
    description = "Docker swarm (udp)"
    from_port   = 0
    to_port     = 0
    protocol    = "udp"
    cidr_blocks = [
      data.aws_vpc.main.cidr_block,
    ]
  }

  egress {
    description = "Docker swarm (tcp)"
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = [
      data.aws_vpc.main.cidr_block,
    ]
  }

  tags = {
    Name = "${var.name} Docker"
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }
}

resource "aws_security_group" "daemon_ssh" {
  count       = var.daemon_ssh ? 1 : 0
  name        = "docker-daemon-ssh"
  description = "Docker Daemon SSH port"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      var.daemon_cidr_block,
    ]
  }

  tags = {
    Name = "${var.name} Docker Daemon SSH"
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }
}

resource "aws_security_group" "daemon" {
  count       = var.daemon_tls ? 1 : 0
  name        = "docker-daemon"
  description = "Docker Daemon port"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 2376
    to_port   = 2376
    protocol  = "tcp"
    cidr_blocks = [
      var.daemon_cidr_block,
    ]
  }

  tags = {
    Name = "${var.name} Docker TLS Daemon"
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = [
    "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "swarm-access-role-policy" {
  statement {
    actions = [
      "ec2:DescribeVpcs",
    ]

    resources = [
      "*",
    ]
  }
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:PutLogEvents",
    ]

    resources = [
      "*",
    ]
  }
  statement {
    actions = [
      "iam:ListSSHPublicKeys",
      "iam:GetSSHPublicKey",
    ]

    resources = [for o in data.aws_iam_user.ssh_users : o.arn]
  }

}

data "aws_iam_user" "ssh_users" {
  for_each  = toset(var.ssh_users)
  user_name = each.key
}

resource "aws_iam_policy" "swarm-access-role-policy" {
  name   = "${local.dns_name}-swarm-ec2-policy"
  policy = data.aws_iam_policy_document.swarm-access-role-policy.json
}

resource "aws_iam_role_policy_attachment" "swarm-access-role-policy" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.swarm-access-role-policy.arn
}

resource "aws_iam_role" "ec2" {
  name               = "${local.dns_name}-ec2"
  description        = "Allows reading of infrastructure secrets"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.dns_name}-ec2"
  role = aws_iam_role.ec2.name
}


resource "aws_sns_topic" "alarms" {
  name = "${local.dns_name}-alarms"
}

resource "aws_cloudwatch_log_group" "main" {
  count             = (var.cloudwatch_logs && var.cloudwatch_single_log_group) ? 1 : 0
  name              = local.dns_name
  retention_in_days = var.cloudwatch_retention_in_days

  tags = {
    Environment = var.name
    Name        = var.name
  }
}
