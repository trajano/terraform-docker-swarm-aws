# AWS Docker Swarm Terraform Module

This is a Terraform configuration that sets up a Docker Swarm on an existing VPC with a configurable amount of managers and worker nodes. The swarm is configured to have [SSH daemon access][ssh-daemon] enabled by default with [EC2 instance monitoring](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html).

## Terraformed layout

In the VPC there will be 2 x _number of availability zones in region_ subnets created. Each EC2 instance will be placed in an subnet in a round-robin fashion.

There are no elastic IPs allocated in the module in order to prevent using up the elastic IP allocation for the VPC. It is up to the caller to set that up.

## Prerequisites

The `aws` provider is configured in your TF file.

AWS permissions to do the following:

- Manage EC2 resource
- Security Groups
- IAM permissions
- SNS
- Cloudwatch Alarms

The `examples/iam-policies` shows the policy JSONs that are used.

For earlier versions of the module, *S3 Create and Access* was required to store the tokens.  Tags are used in the current releases to save on S3 costs.  This method is has been depreacted and removed as of v6.0.0.

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

## Cloud Config merging

The default merge rules of cloud-config is used which may yield unexpected results (see [cloudconfig merge behaviours](https://jen20.com/2015/10/04/cloudconfig-merging.html)) if you are changing existing keys. To bring back the merge behaviour from 1.2 add

    merge_how: "list(append)+dict(recurse_array)+str()"

## Upgrading the swarm

Though `yum update` can simply update the software, it may be required to update things that are outside such as updates to the module itself, `cloud_config_extra` information or AMI updates.  For this to work, you need to have at least 3 managers otherwise you'd lose raft consensus and have to rebuild the swarm from scratch.

### Example of how to upgrade a 3 manager swawrm

Upgrading a 3 manager swarm needs to be done one at a time to prevent raft consensus loss.

1. Make `manager0` leave the swarm by executing `ssh <username>@<manager0> sudo /root/bin/leave-swarm.sh`
2. Taint `manager0` from the command line `terraform taint module.docker-swarm.aws_instance.managers[0]`
3. Rebuild `manager0` from the command line `terraform apply`
4. Wait until `manager0` rejoins the swarm by checking `docker node ls`
5. Make `manager1` leave the swarm by executing  `ssh <username>@<manager1> sudo /root/bin/leave-swarm.sh`
6. Taint `manager1` from the command line `terraform taint module.docker-swarm.aws_instance.managers[1]`
7. Rebuild `manager1` from the command line `terraform apply`
8. Wait until `manager1` rejoins the swarm by checking `docker node ls`
9. Make `manager2` leave the swarm by executing `ssh <username>@<manager2> sudo /root/bin/leave-swarm.sh`
10. Taint `manager2` from the command line `terraform taint module.docker-swarm.aws_instance.managers[2]`
11. Rebuild `manager2` from the command line `terraform apply`
12. Wait until `manager2` rejoins the swarm by checking `docker node ls`
13. Prune the nodes that are down and are drained `ssh <username>@<manager0> sudo /root/bin/prune-nodes.sh`

### Upgrading the worker nodes

A future relase of this would utilize auto-scaling for now this needs to be done manually

1. Drain and remove the worker node(s) from the swarm using `ssh <username>@<manager0> sudo /root/bin/rm-workers.sh <nodename[s]>`
2. Taint the workers that are removed from the command line `terraform taint module.docker-swarm.aws_instance.workers[#]`
3. Rebuild the workers from the command line `terraform apply`

## Other tips

- Don't use Terraform to provision your containers, just let it build the infrastructure and add the hooks to connect it to your build system.
- To use a different version of Docker create a custom cloud config with

      packages:
      - [docker, 18.03.1ce-2.amzn2]
      - haveged
      - python2-boto3
      - yum-cron
      - ec2-instance-connect
      - perl-Switch
      - perl-DateTime
      - perl-Sys-Syslog
      - perl-LWP-Protocol-https
      - perl-Digest-SHA.x86_64

- Add additional SSH users using `sudo /root/bin/add-docker-user.sh <username> <ssh key string>`.  Note this creates users in such a way that it only allows the use of `docker context`
- The servers are built with ElasticSearch and Redis containers in mind and the following documents specify the changes that are implemented as part of Terraform:
  - [ElasticSearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#docker-prod-prerequisites)
  - [Redis](https://redis.io/topics/faq#background-saving-fails-with-a-fork-error-under-linux-even-if-i-have-a-lot-of-free-ram)

[ssh-daemon]: https://github.com/docker/cli/pull/1014
[haveged]: http://issihosts.com/haveged/
[ec2-instance-connect]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Connect-using-EC2-Instance-Connect.html
