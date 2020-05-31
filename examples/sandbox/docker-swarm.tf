data "template_file" "cloud-config" {
  template = file("template.cloud-config")

  vars = {
    ssh_key       = var.ssh_key
    repo_url      = var.repo_url
    repo_username = var.repo_username
    repo_password = var.repo_password
  }
}

module "docker-swarm" {
  # source  = "trajano/swarm-aws/docker"
  # version = "~>1.2"
  source = "../../"

  name               = var.name
  vpc_id             = aws_vpc.main.id
  managers           = var.managers
  workers            = var.workers
  cloud_config_extra = data.template_file.cloud-config.rendered
  instance_type      = var.instance_type
  daemon_count       = length(aws_eip.daemons)
  daemon_eip_ids     = aws_eip.daemons.*.id

  exposed_security_group_ids = [
    aws_security_group.exposed.id,
  ]
}

terraform {
  required_version = ">= 0.12"
}
