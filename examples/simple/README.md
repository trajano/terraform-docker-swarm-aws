Mostly default example
======================
This example showsthe default of a simple 3-manager swarm in the AWS `us-east-1`.  In addition some customizations done for the provisioning are:

1. exposing two Elastic IPs (as there's a limit to Elastic IPs being provisioned)
2. exposing the SSH, HTTP and HTTPS ports
3. adding two custom users with their SSH keys
4. Outputting the IPs.

## Customizing

* `users.cloud-config` should be modified to have your SSH public key.
* Change the name of the VPC in *docker-swarm.tf*.
* Set the region for the `aws` provider in *vpc.tf*.
