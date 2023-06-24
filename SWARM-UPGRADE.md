# Upgrading the swarm

See SWARM-UPGRADE.md

Though `yum update` can simply update the software, it may be required to update things that are outside such as updates to the module itself, `cloud_config_extra` information or AMI updates.  For this to work, you need to have at least 3 managers otherwise you'd lose raft consensus and have to rebuild the swarm from scratch.

## Example of how to upgrade a 3 manager swawrm

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

## Upgrading the worker nodes

A future relase of this would utilize auto-scaling for now this needs to be done manually

1. Drain and remove the worker node(s) from the swarm using `ssh <username>@<manager0> sudo /root/bin/rm-workers.sh <nodename[s]>`
2. Taint the workers that are removed from the command line `terraform taint module.docker-swarm.aws_instance.workers[#]`
3. Rebuild the workers from the command line `terraform apply`

[ssh-daemon]: https://github.com/docker/cli/pull/1014
[haveged]: http://issihosts.com/haveged/
[ec2-instance-connect]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Connect-using-EC2-Instance-Connect.html
