# AWS Docker Swarm Terraform Module

This is a Terraform configuration that sets up a Docker Swarm on an existing VPC with a configurable amount of managers and worker nodes. The swarm is configured to have TLS enabled.

## Terraformed layout

In the VPC there will be 2 x _number of availability zones in region_ created.

There are no elastic IPs allocated in the module in order to prevent using up the elastic IP allocation for the VPC. It is up to the caller to set that up.

## Prerequisites

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

## Example

The `examples/simple` folder shows an example of how to use this module.

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
