resource "tls_private_key" "managers" {
  count     = "${var.managers}"
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "managers" {
  count           = "${var.managers}"
  key_algorithm   = "${tls_private_key.managers.*.algorithm[count.index]}"
  private_key_pem = "${tls_private_key.managers.*.private_key_pem[count.index]}"

  subject {
    common_name = "manager${count.index}"
  }

  dns_names = [
    "manager${count.index}",
    "localhost",
  ]

  ip_addresses = [
    "${cidrhost(aws_subnet.managers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}",
    "127.0.0.1",
  ]
}

data "template_file" "init_manager" {
  count    = "${var.managers}"
  template = "${file("${path.module}/init_manager.py")}"

  vars {
    s3_bucket      = "${aws_s3_bucket.terraform.bucket}"
    instance_index = "${count.index}"
    private_key    = "${tls_private_key.managers.*.private_key_pem[count.index]}"
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
    filename     = "init_manager.py"
    content      = "${data.template_file.init_manager.*.rendered[count.index]}"
    content_type = "text/x-shellscript"
  }
}

resource "aws_instance" "managers" {
  count                  = "${var.managers}"
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

