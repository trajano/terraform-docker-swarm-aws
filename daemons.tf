provider "tls" {
  version = "~> 1.2"
}

data "aws_eip" "daemons" {
  # count = "${length(var.manager_eip_ids)}"
  count = "${var.manager_eip_count}"
  id    = "${var.manager_eip_ids[count.index]}"
}

resource "tls_cert_request" "daemons" {
  count           = "${var.manager_eip_count}"
  key_algorithm   = "${var.manager_private_key_algorithm}"
  private_key_pem = "${var.manager_private_key_pems[count.index]}"

  subject {
    common_name = "manager${count.index}"
  }

  dns_names = "${concat(var.manager_dns, list("manager${count.index}", "localhost"))}"

  #  ip_addresses = "${concat(data.aws_eip.daemons.*.public_ip, list(cidrhost(aws_subnet.managers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index), "127.0.0.1"))}"
  ip_addresses = [
    "${cidrhost(aws_subnet.managers.*.cidr_block[count.index % length(data.aws_availability_zones.azs.*.names)], 10 + count.index)}",
    "127.0.0.1",
  ]
}

resource "aws_eip_association" "daemons" {
  count         = "${var.manager_eip_count}"
  allocation_id = "${var.manager_eip_ids[count.index]}"
  instance_id   = "${aws_instance.managers.*.id[count.index]}"
}
