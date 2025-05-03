module "docker-swarm" {
  # source  = "trajano/swarm-aws/docker"
  # version = "~>1.2"
  source = "../../"

  name     = var.name
  vpc_id   = aws_vpc.main.id
  managers = var.managers
  workers  = var.workers
  cloud_config_extra = templatefile("template.cloud-config", {
    ssh_key       = var.ssh_key
  })
  instance_type               = var.instance_type
  cloudwatch_logs             = true
  cloudwatch_single_log_group = true
  generate_host_keys          = true
  ssh_authorization_method    = "iam"
  ssh_users = [
    "trajano",
    "docker-user",
  ]
  key_name = aws_key_pair.deployer.key_name
  extra_tags = {
    "foo" = "bar"
  }

  additional_security_group_ids = [
    aws_security_group.exposed.id,
  ]
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.name}-deployer-key"
  public_key = var.ssh_key
}
