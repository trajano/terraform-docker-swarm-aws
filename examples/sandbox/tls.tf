# Be careful when using this as the tls_private_key stores the private key unencrypted in the Terraform backend.
resource "tls_private_key" "daemons" {
  count     = "${aws_eip.managers.count}"
  algorithm = "RSA"
}

resource "tls_private_key" "ca" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = "${tls_private_key.ca.algorithm}"
  private_key_pem = "${tls_private_key.ca.private_key_pem}"

  subject {
    common_name = "example CA"
  }

  validity_period_hours = 12

  allowed_uses = [
    "cert_signing",
  ]
}

resource "tls_locally_signed_cert" "daemons" {
  count              = "${aws_eip.managers.count}"
  cert_request_pem   = "${module.docker-swarm.daemon_cert_request_pems[count.index]}"
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 12

  allowed_uses = [
    "server_auth",
  ]
}
