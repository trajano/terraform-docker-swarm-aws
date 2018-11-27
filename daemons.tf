provider "tls" {
  version = "~> 1.2"
}

data "aws_eip" "daemons" {
  count = "${var.daemon_count}"
  id    = "${var.daemon_eip_ids[count.index]}"
}

resource "tls_cert_request" "daemons" {
  count           = "${var.daemon_count}"
  key_algorithm   = "${var.daemon_private_key_algorithm}"
  private_key_pem = "${var.daemon_private_key_pems[count.index]}"

  subject {
    common_name = "manager${count.index}"
  }

  dns_names = "${concat(var.daemon_dns, list("manager${count.index}", "localhost"))}"

  ip_addresses = [
    "${data.aws_eip.daemons.*.public_ip[count.index]}",
    "${cidrhost(aws_subnet.managers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}",
    "127.0.0.1",
  ]
}

data "template_file" "init_daemon" {
  count    = "${var.managers}"
  template = "${file("${path.module}/init_daemon.py")}"

  vars {
    daemon_count   = "${var.daemon_count}"
    instance_index = "${count.index}"
    private_key    = "${count.index < var.daemon_count ? element(var.daemon_private_key_pems, count.index) : ""}"
    cert           = "${count.index < var.daemon_count ? element(var.daemon_cert_pems, count.index): ""}"
    ca_cert        = "${var.daemon_ca_cert_pem}"
  }
}

resource "aws_eip_association" "daemons" {
  count         = "${var.daemon_count}"
  allocation_id = "${var.daemon_eip_ids[count.index]}"
  instance_id   = "${aws_instance.managers.*.id[count.index]}"
}
