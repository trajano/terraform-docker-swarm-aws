# output "daemon_ip_addresses" {
#   value = aws_eip.daemons.*.public_ip
# }

output "manager_ips" {
  value = module.docker-swarm.manager_ips
}

output "worker_ips" {
  value = module.docker-swarm.worker_ips
}

