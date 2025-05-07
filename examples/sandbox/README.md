# Sandbox

This example is used for integration testing with the current code base with TLS removed and provides a bastion server. This uses the source "../.." rather than the release copy.

## Connecting to the Docker daemon

    docker -H ssh://username@bastionIP <commands>

## Using a private docker-ce repo

This example provides an example of using a private yum repository mirror in this case it is hosted in a private Sonatype Nexus server to use a managed resource. It disables upgrades and fast mirror as well.

Note the slowest part is the `instance_type` on a `t3.micro` the time to finish cloud-init is over 200 seconds the time is primarily spent on the `yum install docker-ce`. For a `t3.small` it drops down to under 150 seconds and `t3.medium` is under 100 seconds. The results are in `/var/log/cloud-init-output.log`.

See the `variables.tf` file to see what to set in `terraform.tfvars`
