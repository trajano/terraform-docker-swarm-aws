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
  }

  part {
    filename     = "init_daemon.py"
    content      = "${data.template_file.init_daemon.*.rendered[count.index]}"
    content_type = "text/x-shellscript"
  }

  part {
    filename     = "init_manager.py"
    content      = "${data.template_file.init_manager.*.rendered[count.index]}"
    content_type = "text/x-shellscript"
  }
}

resource "aws_instance" "managers" {
  depends_on = [
    "aws_s3_bucket.terraform",
  ]

  count         = "${var.managers}"
  ami           = "${data.aws_ami.base_ami.id}"
  instance_type = "${var.instance_type}"
  subnet_id     = "${aws_subnet.managers.*.id[count.index % length(data.aws_availability_zones.azs.*.names)]}"
  private_ip    = "${cidrhost(aws_subnet.managers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}"

  # workaround as noted by https://github.com/hashicorp/terraform/issues/12453#issuecomment-284273475
  vpc_security_group_ids = [
    "${split(",", count.index < var.daemon_count ? join(",", local.daemon_security_group_ids) : join(",", local.security_group_ids))}",
  ]

  iam_instance_profile = "${aws_iam_instance_profile.ec2.name}"
  user_data_base64     = "${data.template_cloudinit_config.managers.*.rendered[count.index]}"
  key_name             = "${var.key_name}"

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
