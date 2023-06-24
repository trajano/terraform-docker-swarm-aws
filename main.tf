locals {
  dns_name = lower(replace(var.name, " ", "-"))
  security_group_ids = concat(
    var.exposed_security_group_ids,
    var.additional_security_group_ids,
    [
      aws_security_group.docker.id
    ],
  )
  instance_type_manager           = coalesce(var.instance_type_manager, var.instance_type)
  instance_type_worker            = coalesce(var.instance_type_worker, var.instance_type)
  burstable_instance_type_manager = length(regexall("^t\\d\\..*", local.instance_type_manager)) > 0
  burstable_instance_type_worker  = length(regexall("^t\\d\\..*", local.instance_type_worker)) > 0
}

data "aws_region" "current" {}

data "aws_availability_zones" "azs" {
  exclude_names = var.excluded_availability_zones
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
  tags = {
    Name = "${var.name} Docker"
  }

  timeouts {
    create = "2m"
    delete = "2m"
  }
}
resource "aws_security_group_rule" "docker-swarm" {
  security_group_id = aws_security_group.docker.id
  type              = "ingress"
  description       = "Docker swarm management"
  from_port         = 2377
  to_port           = 2377
  protocol          = "tcp"
  cidr_blocks = [
    data.aws_vpc.main.cidr_block,
  ]
}

resource "aws_security_group_rule" "docker-network-discovery-tcp" {
  security_group_id = aws_security_group.docker.id
  type              = "ingress"
  description       = "Docker container network discovery"
  from_port         = 7946
  to_port           = 7946
  protocol          = "tcp"
  cidr_blocks = [
    data.aws_vpc.main.cidr_block,
  ]
}

resource "aws_security_group_rule" "docker-network-discovery-udp" {
  security_group_id = aws_security_group.docker.id
  type              = "ingress"
  description       = "Docker container network discovery"
  from_port         = 7946
  to_port           = 7946
  protocol          = "udp"
  cidr_blocks = [
    data.aws_vpc.main.cidr_block,
  ]
}

resource "aws_security_group_rule" "docker-overlay-network" {
  security_group_id = aws_security_group.docker.id
  type              = "ingress"
  description       = "Docker overlay network"
  from_port         = 4789
  to_port           = 4789
  protocol          = "udp"
  cidr_blocks = [
    data.aws_vpc.main.cidr_block,
  ]
}

resource "aws_security_group_rule" "docker-egress-udp" {
  security_group_id = aws_security_group.docker.id
  type              = "egress"
  description       = "Docker swarm (udp)"
  from_port         = 0
  to_port           = 0
  protocol          = "udp"
  cidr_blocks = [
    data.aws_vpc.main.cidr_block,
  ]
}

resource "aws_security_group_rule" "docker-egress-tcp" {
  security_group_id = aws_security_group.docker.id
  type              = "egress"
  description       = "Docker swarm (tcp)"
  from_port         = 0
  to_port           = 0
  protocol          = "tcp"
  cidr_blocks = [
    data.aws_vpc.main.cidr_block,
  ]
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
      "ssm:GetParameter",
    ]

    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:*:parameter/${local.cloudwatch_agent_parameter}"
    ]
  }
}

data "aws_iam_policy_document" "swarm-access-role-policy-ssh" {
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

resource "aws_iam_policy" "swarm-access-role-policy-ssh" {
  count  = var.ssh_authorization_method == "iam" ? 1 : 0
  name   = "${local.dns_name}-swarm-ec2-policy-ssh"
  policy = data.aws_iam_policy_document.swarm-access-role-policy-ssh.json
}

resource "aws_iam_role_policy_attachment" "swarm-access-role-policy-ssh" {
  count      = var.ssh_authorization_method == "iam" ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.swarm-access-role-policy-ssh[0].arn
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
  name              = "${local.dns_name}-alarms"
  display_name      = "${local.dns_name} alarms"
  kms_master_key_id = var.sns_kms_id
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

