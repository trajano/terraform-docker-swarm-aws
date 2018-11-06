# AWS Docker Swarm Terraform Module

This is a Terraform configuration that sets up a Docker Swarm on an existing VPC with a configurable amount of managers and worker nodes. The swarm is configured to have TLS enabled.

## Terraformed layout

In the VPC there will be 2 x _number of availability zones in region_ created.

There are no elastic IPs allocated in the module in order to prevent using up the elastic IP allocation for the VPC. It is up to the caller to set that up.

## Preequisites

The `aws` plugin is configured in your TF file.

AWS permissions to do the following

* Manage EC2 resource
* Security Groups
* IAM permissions
* S3 Create and Access

## Limitations

- Maximum of 240 docker managers.
- Maximum of 240 docker workers.
- Only one VPC and therefore only one AWS region.
- The VPC must have to following properties
  - The VPC should have access to the Internet
  - The DNS hostnames support must be enabled (otherwise the node list won't work too well)
  - VPC must have a CIDR block mask of `/16`.

## Inputs

### Required

- `name` specifies the name of the swarm that is going to be built. It is used for names and DNS names.
- `vpc_id` specifies the VPC to use for the swarm. This needs to be present.

### Optional

- `exposed_security_group_ids` this are security group IDs that specifies the ports that would be exposed by the swarm for external access. Note that the security groups defined neither any egress access nor ssh access to the swarm.
- `manager_subnet_segment_start` this is added to the index to represent the third segment of the IP address. Defaults to `10`
- `worker_subnet_segment_start` this is added to the index to represent the third segment of the IP address. Defaults to `110`
- `cloud_config_extra` this points to a file that contains additional blocks to be added to the cloud-config file. Ideally this is where you would put the `users` block otherwise no one can login to the EC2 instances.

## Outputs

- `manager_instance_ids` AWS instance IDs for the managers.
- `worker_instance_ids` AWS instance IDs for the managers.

## Example

The following shows an example of how to use the module.  The contents are in `examples/simple` folder

### vpc.tf

This shows an example of how to set up the VPC and security groups with the required elements for the module also exposes SSH, HTTP and HTTPS along with allowing the swarm to access the Internet.

```
provider "aws" {
}

resource "aws_vpc" "main" {
  cidr_block           = "10.95.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

resource "aws_security_group" "exposed" {
  name        = "exposed"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
```

### users.cloud-config

In order to access the servers you need to define administrators and their SSH keys:

```
users:
- name: deployer
  ssh-authorized-keys:
  - ssh-rsa ...
  sudo: ['ALL=(ALL) NOPASSWD: /usr/bin/docker']
- name: admin
  ssh-authorized-keys:
  - ssh-rsa ...
  sudo: ['ALL=(ALL) NOPASSWD:ALL']
```

### docker-swarm.tf

The module is then created as follows

```
module "docker-swarm" {
  source  = "trajano/swarm-aws/docker"
  version = "1.0.3"

  name   = "My VPC Swarm"
  vpc_id = "${aws_vpc.main.id}"
  cloud_config_extra = "${file("users.cloud-config")}"
  exposed_security_group_ids = [
    "${aws_security_group.exposed.id}",
  ]
}
```

### eips.tf

In order to ensure that there is a static set of IPs, you can use Elastic IPs. Just note that there is a limit of number of elastic IPs per VPC. As such the creation of the elastic IPs is not performed by the module.

```
resource "aws_eip" "managers" {
  count    = "2"
  instance = "${module.docker-swarm.manager_instance_ids[count.index]}"
  vpc      = true
}

output "manager_ip_addresses" {
  value = "${aws_eip.managers.*.public_ip}"
}
```

## Upgrading the swarm

Though `yum update` can simply update the software, it may be required to update things that are outside such as updates to the module itself, `cloud_config_extra` information or AMI updates. To do such an update without having to recreate the swarm it is best to do it one manager node at a time and do `manager0` last. This module ignores changes to cloud config or AMI information in order to prevent updates of those to force a new resource inadvertently.

Before forcing an update, the node cleanly leave swarm otherwise there would be a dangling node in the list. To do this on an an existing manager node run the following to remove the `manager1` for example from the swarm:

    sudo docker node demote manager1
    sudo docker node update --availability drain

Once the `manager1` no longer has any running containers, on `manager1`

    sudo docker swarm leave

Once it has left the swarm, on the other manager node remove the `manager1`.

    sudo docker node rm manager1

Then force an update by tainting the resource. For `manager1` this will be:

    terraform taint -module=docker-swarm aws_instance.managers.1
    terraform apply

By doing the above, you can let the raft consensus recover itself. Make sure you verify your node list before removing another node using `sudo docker node ls` and ensuring all the nodes are there.

Before updating `manager0` make sure `manager1` is up and running as it checks it it can join using `manager1` otherwise it will initialize a new swarm.
