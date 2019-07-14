output "daemon_ip_addresses" {
  value = aws_eip.managers.*.public_ip
}

output "manager_ips" {
  value = module.docker-swarm.manager_ips
}

output "worker_ips" {
  value = module.docker-swarm.worker_ips
}

output "ca_cert_pem" {
  value     = tls_self_signed_cert.ca.cert_pem
  sensitive = true
}

output "client_private_key_pem" {
  value     = tls_private_key.client.private_key_pem
  sensitive = true
}

output "client_cert_pem" {
  value     = tls_locally_signed_cert.client.cert_pem
  sensitive = true
}

