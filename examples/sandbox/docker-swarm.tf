data "template_file" "cloud-config" {
  template = "${file("template.cloud-config")}"

  vars {
    ssh_key       = "${var.ssh_key}"
    repo_url      = "${var.repo_url}"
    repo_username = "${var.repo_username}"
    repo_password = "${var.repo_password}"
  }
}

module "docker-swarm" {
  # source  = "trajano/swarm-aws/docker"
  # version = "~>1.2"
  source = "../../"

  name               = "My VPC Swarm"
  vpc_id             = "${aws_vpc.main.id}"
  managers           = "${var.managers}"
  workers            = "${var.workers}"
  cloud_config_extra = "${data.template_file.cloud-config.rendered}"
  instance_type      = "${var.instance_type}"

  exposed_security_group_ids = [
    "${aws_security_group.exposed.id}",
  ]
}
