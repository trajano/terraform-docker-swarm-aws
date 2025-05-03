# `/root/bin/` Script Reference

## `add-docker-user.sh`
Creates a Docker-enabled system user and sets up SSH access restricted to `docker system dial-stdio`.

## `cloudwatch-off`
Stops and disables the CloudWatch Agent, and reconfigures Docker to stop using the `awslogs` log driver.

## `cloudwatch-on`
Re-enables and starts the CloudWatch Agent, and reconfigures Docker to resume using the `awslogs` log driver.

## `leave-swarm.sh`
Gracefully removes this node from the Docker Swarm by draining, demoting, and leaving.

## `prune-nodes.sh`
Finds and removes unreachable manager nodes that are marked Down and Drain.

## `rm-workers.sh`
Drains and force-removes the specified worker nodes from the Docker Swarm.
