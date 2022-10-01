data "template_file" "cloud-config" {
  template = file("template.cloud-config")

  vars = {
    ssh_key = var.ssh_key
  }
}

module "docker-swarm" {
  # source  = "trajano/swarm-aws/docker"
  # version = "~>1.2"
  source = "../../"

  name                        = var.name
  vpc_id                      = aws_vpc.main.id
  managers                    = var.managers
  workers                     = var.workers
  cloud_config_extra          = data.template_file.cloud-config.rendered
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

  additional_security_group_ids = [
    aws_security_group.exposed.id,
  ]

  cloudwatch_log_stream_template = "{{ with split .Name \".\" }}{{ index . 0 }}{{end}}"
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.name}-deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD2Io+Qf9A8oD9WGHK6lPqka0fkdMsZYCY0ElQaUfFLUd6jsITyfM44Au8kUVf9MRlfKWZH6H2UhKgOxBwlII2aEdoERwhu8w+d9VQHk3ifubCqaTSNgXwygup0JzaMsgPxBeagpztaTkyT/wwyG+sc8+Y2aa0Wo9jsyJkN/r4DD1EX9mv5ii+1j98UznvisO2w9+TQEuWJBOEddaIcIcOjiEVeal7gT1whRGjLxI58gDK7VhVD28hc57XAfJ3DjKefD9YVTxjHH6kKxVEqZWnWGNiIAXslOUEkkoVcSFLamM3rJZQq6hmjdt7PjpzGTNqQcxPfVsZ1deA6DeH7aEj5 64:92:a0:87:a1:fd:72:70:21:3e:8e:fd:bb:a5:fc:54 imported-openssh-key"
}
