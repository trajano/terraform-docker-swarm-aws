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
    content = file("${path.module}/common.cloud-config")
  }

  part {
    filename = "bootcmd.cloud-config"
    content = yamlencode({
      "bootcmd" : [
        ["cloud-init-per", "once", "amazon-linux-extras-docker", "amazon-linux-extras", "install", "docker"],
        ["cloud-init-per", "once", "amazon-linux-extras-epel", "amazon-linux-extras", "install", "epel"],
        ["cloud-init-per", "boot", "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl", "-a", "fetch-config", "-m", "ec2", "-s", "-c", "ssm:${local.cloudwatch_agent_parameter}"],
      ],
      "runcmd" : [
        ["sysctl", "-w", "vm.max_map_count=262144"],
        ["sysctl", "-w", "fs.file-max=65536"],
        ["sysctl", "-w", "vm.overcommit_memory=1"],
        ["ulimit", "-n", "65536"],
        ["ulimit", "-u", "4096"],
        ["/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl", "-a", "fetch-config", "-m", "ec2", "-s", "-c", "ssm:${local.cloudwatch_agent_parameter}"]
      ]
    })
    content_type = "text/cloud-config"
  }

  part {
    filename = "ssh_keys.cloud-config"
    content = var.generate_host_keys ? yamlencode({
      "ssh_keys" : {
        "rsa_private" : "${tls_private_key.workers-rsa[count.index].private_key_openssh}",
        "rsa_public" : "${tls_private_key.workers-rsa[count.index].public_key_openssh}",
        "ecdsa_private" : "${tls_private_key.workers-ecdsa[count.index].private_key_openssh}",
        "ecdsa_public" : "${tls_private_key.workers-ecdsa[count.index].public_key_openssh}",
        "ed25519_private" : "${tls_private_key.workers-ed25519[count.index].private_key_openssh}",
        "ed25519_public" : "${tls_private_key.workers-ed25519[count.index].public_key_openssh}",
      },
      "no_ssh_fingerprints" : false,
      "ssh" : {
        "emit_keys_to_console" : false
      }
    }) : ""
    content_type = "text/cloud-config"
  }

  part {
    filename     = "extra.cloud-config"
    content      = var.cloud_config_extra
    merge_type   = var.cloud_config_extra_merge_type
    content_type = "text/cloud-config"
  }

  part {
    filename = "init_worker.py"
    content = templatefile(
      "${path.module}/init_node.py",
      {
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
  ami                         = data.aws_ami.base_ami.id
  instance_type               = local.instance_type_worker
  associate_public_ip_address = var.associate_public_ip_address
  subnet_id                   = aws_subnet.workers[count.index % length(data.aws_availability_zones.azs.names)].id
  private_ip = cidrhost(
    aws_subnet.workers[count.index % length(data.aws_availability_zones.azs.names)].cidr_block,
    10 + count.index,
  )

  vpc_security_group_ids = local.security_group_ids

  iam_instance_profile = aws_iam_instance_profile.ec2.name
  user_data_base64     = data.cloudinit_config.workers[count.index].rendered
  key_name             = var.key_name

  tags = {
    Name = "${var.name} worker ${count.index}"
    Role = "worker"
  }

  root_block_device {
    volume_size = var.volume_size
    encrypted   = true
  }

  ebs_block_device {
    device_name = "xvdf"
    volume_size = var.swap_size
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = var.metadata_http_tokens_required ? "required" : "optional"
  }

  ebs_optimized = true
  monitoring    = var.detailed_monitoring

  lifecycle {
    ignore_changes = [
      ami,
      root_block_device,
      ebs_block_device,
      ebs_optimized,
      instance_type,
      user_data_base64,
      subnet_id,
      private_ip,
      availability_zone,
    ]
  }

  credit_specification {
    cpu_credits = "standard"
  }
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
  tags                      = {}
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
  tags                      = {}
  threshold                 = 85
}

resource "aws_cloudwatch_log_group" "workers" {
  count             = (var.cloudwatch_logs && !var.cloudwatch_single_log_group) ? var.workers : 0
  name              = "${local.dns_name}-worker${count.index}"
  retention_in_days = var.cloudwatch_retention_in_days
  kms_key_id        = var.cloudwatch_kms_key_id
  tags = {
    Environment = var.name
    Name        = "${var.name} worker ${count.index}"
    Node        = "${local.dns_name}-worker${count.index}"
  }
}
