# Using TLS requires the aws_eip to be not associated to an instance until after the instance is created.
resource "aws_eip" "daemons" {
  count = var.daemon_count
  vpc   = true
}

resource "aws_eip_association" "daemons" {
  count         = var.daemon_count
  allocation_id = aws_eip.daemons[count.index].id
  instance_id   = module.docker-swarm.manager_instance_ids[count.index]
}

