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
    content      = "${var.cloud_config_extra}"
    content_type = "text/cloud-config"
  }

  part {
    filename     = "init_worker.py"
    content      = "${data.template_file.init_worker.*.rendered[count.index]}"
    content_type = "text/x-shellscript"
  }
}

resource "aws_instance" "workers" {
  count                  = "${var.workers}"
  ami                    = "${data.aws_ami.base_ami.id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${aws_subnet.workers.*.id[(count.index + var.managers) % length(data.aws_availability_zones.azs.*.names)]}"
  private_ip             = "${cidrhost(aws_subnet.workers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}"
  vpc_security_group_ids = ["${local.security_group_ids}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ec2.name}"
  user_data_base64       = "${data.template_cloudinit_config.workers.*.rendered[count.index]}"
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
