# Sandbox

This example is used for integration testing with the current code base. This uses the source "../.." rather than the release copy.

## Using a private docker-ce repo

This example provides an example of using a private yum repository mirror in this case it is hosted in a private Sonatype Nexus server to use a managed resource. It disables upgrades and fast mirror as well.

Note the slowest part is the `instance_type` on a `t3.micro` the time to finish cloud-init is over 200 seconds the time is primarily spent on the `yum install docker-ce`. For a `t3.small` it drops down to under 150 seconds and `t3.medium` is under 100 seconds. The results are in `/var/log/cloud-init-output.log`.

See the `variables.tf` file to see what to set in `terraform.tfvars`

## Connecting to the Docker daemon

    export DOCKER_CERT_PATH=<directory where you're extracting the PEM files>
    export DOCKER_TLS_VERIFY=1
    export DOCKER_HOST=tcp://<ip>:2376
    terraform output client_private_key_pem > key.pem
    terraform output client_cert_pem > cert.pem
    terraform output ca_cert_pem > ca.pem
