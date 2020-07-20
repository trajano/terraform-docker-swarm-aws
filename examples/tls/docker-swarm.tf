module "docker-swarm" {
  # source  = "trajano/swarm-aws/docker"
  # version = "~>1.2"
  source = "../../"

  name                    = "My VPC Swarm"
  vpc_id                  = aws_vpc.main.id
  managers                = var.managers
  workers                 = var.workers
  cloud_config_extra      = file("users.cloud-config")
  instance_type           = var.instance_type
  daemon_count            = length(aws_eip.managers)
  daemon_eip_ids          = aws_eip.managers.*.id
  daemon_private_key_pems = tls_private_key.daemons.*.private_key_pem
  daemon_cert_pems        = tls_locally_signed_cert.daemons.*.cert_pem
  daemon_ca_cert_pem      = tls_self_signed_cert.ca.cert_pem
  daemon_tls              = true

  additional_security_group_ids = [
    aws_security_group.exposed.id,
  ]
}

