# ECDSA key with P384 elliptic curve
resource "tls_private_key" "workers-ecdsa" {
  count       = var.generate_host_keys ? var.workers : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# RSA key of size 4096 bits
resource "tls_private_key" "workers-rsa" {
  count     = var.generate_host_keys ? var.workers : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "workers-ed25519" {
  count     = var.generate_host_keys ? var.workers : 0
  algorithm = "ED25519"
}

data "cloudinit_config" "workers" {
  count         = var.workers
  gzip          = "true"
  base64_encode = "true"

  part {
    content = templatefile("${path.module}/common.cloud-config.tmpl", {
      cloudwatch_agent_parameter = local.cloudwatch_agent_parameter
    })
  }

  part {
    filename = "ssh_keys.cloud-config"
    content = join("\n", ["#cloud-config", var.generate_host_keys ? yamlencode({
      "ssh_keys" : {
        "rsa_private" : tls_private_key.workers-rsa[count.index].private_key_openssh,
        "rsa_public" : tls_private_key.workers-rsa[count.index].public_key_openssh,
        "ecdsa_private" : tls_private_key.workers-ecdsa[count.index].private_key_openssh,
        "ecdsa_public" : tls_private_key.workers-ecdsa[count.index].public_key_openssh,
        "ed25519_private" : tls_private_key.workers-ed25519[count.index].private_key_openssh,
        "ed25519_public" : tls_private_key.workers-ed25519[count.index].public_key_openssh
      },
      "no_ssh_fingerprints" : false,
      "ssh" : {
        "emit_keys_to_console" : false
      }
    }) : ""])
    content_type = "text/cloud-config"
  }

  part {
    filename     = "extra.cloud-config"
    content      = var.cloud_config_extra
    content_type = "text/cloud-config"
    merge_type   = var.cloud_config_extra_merge_type
  }

  part {
    filename = "init_worker.py"
    content = templatefile(
      "${path.module}/init_node.py",
      {
        region_name              = data.aws_region.current.name
        instance_index           = count.index
        vpc_name                 = local.dns_name
        cloudwatch_log_group     = var.cloudwatch_logs ? (var.cloudwatch_single_log_group ? local.dns_name : aws_cloudwatch_log_group.managers[count.index].name) : ""
        group                    = "worker"
        ssh_authorization_method = var.ssh_authorization_method
      }
    )
    content_type = "text/x-shellscript"
  }

  part {
    filename     = "extra.sh"
    content      = var.cloud_config_extra_script
    content_type = "text/x-shellscript"
  }
}

resource "aws_instance" "workers" {
  depends_on = [
    aws_instance.managers,
    aws_cloudwatch_log_group.workers,
    aws_cloudwatch_log_group.main,
  ]

  count                       = var.workers
  ami                         = data.aws_ami.workers.id
  instance_type               = local.instance_type_worker
  associate_public_ip_address = var.associate_public_ip_address
  subnet_id                   = aws_subnet.workers[count.index % length(data.aws_availability_zones.azs.names)].id
  private_ip = cidrhost(
    aws_subnet.workers[count.index % length(data.aws_availability_zones.azs.names)].cidr_block,
    10 + count.index,
  )


  # workaround as noted by https://github.com/hashicorp/terraform/issues/12453#issuecomment-284273475
  vpc_security_group_ids = local.security_group_ids

  iam_instance_profile = aws_iam_instance_profile.ec2.name
  user_data_base64     = data.cloudinit_config.workers[count.index].rendered
  key_name             = var.key_name

  private_dns_name_options {
    hostname_type = "resource-name"
  }

  tags = merge({
    Name = "${var.name} worker ${count.index}"
    Role = "worker"
  }, var.extra_tags)

  root_block_device {
    volume_size = var.volume_size
    encrypted   = true
    tags        = var.extra_tags
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.metadata_http_tokens_required ? "required" : "optional"
    http_put_response_hop_limit = var.metadata_put_response_hop_limit
  }

  ebs_optimized = true
  monitoring    = var.detailed_monitoring

  lifecycle {
    ignore_changes = [
      ami,
      root_block_device[0].volume_size,
      ebs_optimized,
      instance_type,
      user_data_base64,
      subnet_id,
      private_ip,
      availability_zone,
      tags["ManagerJoinToken"],
      tags["WorkerJoinToken"],
      tags["CloudInitStartedOn"],
      tags["CloudInitCompletedOn"],
      tags["CloudInitTime"],
    ]
  }

  credit_specification {
    cpu_credits = "standard"
  }
}

resource "aws_ebs_volume" "workers_swap" {
  count             = var.workers
  availability_zone = data.aws_availability_zones.azs.names[count.index % length(data.aws_availability_zones.azs.names)]
  size              = var.swap_size
  encrypted         = true
  tags              = var.extra_tags
}

resource "aws_volume_attachment" "workers_swap" {
  count        = var.workers
  device_name  = "xvdf"
  volume_id    = aws_ebs_volume.workers_swap[count.index].id
  instance_id  = aws_instance.workers[count.index].id
  force_detach = true # optional, but helpful when reapplying
}

resource "aws_cloudwatch_metric_alarm" "low-cpu-credit-workers" {
  count           = local.burstable_instance_type_worker ? var.workers : 0
  actions_enabled = true
  alarm_actions = flatten([
    aws_sns_topic.alarms.arn,
    var.additional_alarm_actions,
  ])
  alarm_name          = "${local.dns_name}-low-cpu-credit-worker${count.index}"
  comparison_operator = "LessThanThreshold"
  datapoints_to_alarm = 1
  dimensions = {
    "InstanceId" = aws_instance.workers[count.index].id
  }
  evaluation_periods        = 1
  insufficient_data_actions = []
  metric_name               = "CPUCreditBalance"
  namespace                 = "AWS/EC2"
  ok_actions                = []
  period                    = 300
  statistic                 = "Average"
  tags                      = var.extra_tags
  threshold                 = 75
  treat_missing_data        = "missing"
}

resource "aws_cloudwatch_metric_alarm" "high-cpu-workers" {
  count           = var.workers
  actions_enabled = true
  alarm_actions = [
    aws_sns_topic.alarms.arn,
  ]
  alarm_name          = "${local.dns_name}-high-cpu-worker${count.index}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 5
  dimensions = {
    "InstanceId" = aws_instance.workers[count.index].id
  }
  evaluation_periods        = 5
  insufficient_data_actions = []
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  ok_actions                = []
  period                    = 60
  statistic                 = "Average"
  tags                      = var.extra_tags
  threshold                 = 85
}

resource "aws_cloudwatch_log_group" "workers" {
  count             = (var.cloudwatch_logs && !var.cloudwatch_single_log_group) ? var.workers : 0
  name              = "${local.dns_name}-worker${count.index}"
  retention_in_days = var.cloudwatch_retention_in_days
  kms_key_id        = var.cloudwatch_kms_key_id
  tags = merge({
    Environment = var.name
    Name        = "${var.name} worker ${count.index}"
    Node        = "${local.dns_name}-worker${count.index}"
  }, var.extra_tags)

}

data "aws_ec2_instance_type" "workers" {
  instance_type = local.instance_type_worker
}


data "aws_ami" "workers" {
  most_recent = true
  owners      = ["amazon", "self"]
  name_regex  = replace(var.ami_name_regex, "ARCH", data.aws_ec2_instance_type.workers.supported_architectures[0])
}


resource "aws_subnet" "workers" {
  count  = length(data.aws_availability_zones.azs.names)
  vpc_id = var.vpc_id
  cidr_block = cidrsubnet(
    data.aws_vpc.main.cidr_block,
    8,
    var.worker_subnet_segment_start + count.index,
  )
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge({
    Name = "${var.name} workers ${data.aws_availability_zones.azs.names[count.index]}"
  }, var.extra_tags)

  availability_zone = data.aws_availability_zones.azs.names[count.index]
}
