data "aws_eip" "daemons" {
  count = var.daemon_count
  id    = var.daemon_eip_ids[count.index]
}

resource "tls_cert_request" "daemons" {
  count           = (var.daemon_tls && var.create_daemon_certificate_request) ? var.daemon_count : 0
  key_algorithm   = var.daemon_private_key_algorithm
  private_key_pem = var.daemon_private_key_pems[count.index]

  subject {
    common_name = "manager${count.index}"
  }

  dns_names = concat(var.daemon_dns, ["manager${count.index}", "localhost"])

  ip_addresses = [
    data.aws_eip.daemons[count.index].public_ip,
    cidrhost(
      aws_subnet.managers[count.index % length(data.aws_availability_zones.azs.*.names)].cidr_block,
      10 + count.index,
    ),
    "127.0.0.1",
  ]
}

data "template_file" "init_daemon" {
  count    = var.managers
  template = file("${path.module}/init_daemon.py")

  vars = {
    daemon_count   = var.daemon_count
    daemon_tls     = var.daemon_tls ? "True" : "False"
    instance_index = count.index
    private_key    = count.index < var.daemon_count ? element(concat(var.daemon_private_key_pems, [""]), count.index) : ""
    cert           = count.index < var.daemon_count ? element(concat(var.daemon_cert_pems, [""]), count.index) : ""
    ca_cert        = var.daemon_ca_cert_pem
  }
}

