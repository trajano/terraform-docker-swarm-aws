resource "aws_eip" "managers" {
  count    = "2"
  instance = module.docker-swarm.manager_instance_ids[count.index]
  vpc      = true
}

output "manager_ip_addresses" {
  value = aws_eip.managers.*.public_ip
}
