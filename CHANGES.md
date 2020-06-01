# Change Log

## 4.0.1

* Allow using Instance Tags to store the join tokens instead of S3.  This is not the default.  Instance tags are used because VPCs are set outside of the module.
* Allow policy version updates in the terraform IAM policies
* Compute region name from instance metadata

## 4.0.0

This version deprecates support for exposing the Docker daemon and removal is expected on 5.0.  It is recommended to switch to use SSH to access to the Docker daemon as it forgoes managing certificates.

* The ssh port is exposed by default controlled by `daemon_ssh` variable.
* The Docker TLS port is not exposed by default controlled by `daemon_tls` variable.
* Use the [cloud-init provider](https://www.terraform.io/docs/providers/cloudinit/index.html) rather than [`template_cloudinit_config`](https://www.terraform.io/docs/providers/template/d/cloudinit_config.html)
* `yum-cron` is enabled to keep your nodes up to date.  Note if you alter the `packages` used in cloud-init, `yum-cron` should be added.
* Add SNS topic for High CPU Utilization and Low CPU Credits for burstable instance types.
* IAM policy JSONs are moved to an example and have been split so they do not exceed 6144 characters.

## 3.1.7

* Ignored `ebs_block_device` changes on workers.  This is to preserve backwards compatibility for swarms that were built without the EBS swap space.
* Increased limits to support Elasticsearch Docker images in [production mode](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html#docker-cli-run-prod-mode) by default.  Also set the requirements for the [file descriptors](https://www.elastic.co/guide/en/elasticsearch/reference/current/file-descriptors.html).
* simple example exposes only one EIP.

## 3.1.6

* Ignored `ebs_block_device` changes on managers.

## 3.1.5

* Use Amazon DNS server
* Allow outbound traffic from Docker security group to other hosts on the VPC

## 3.1.4

* Use an EBS volume to hold the swap rather than a swap file.

## 3.1.2 (2019-09-03)

* Add support to have different instance types for workers and managers.
* Documented how to change the docker version being used.
* Added `aws_s3_bucket_public_access_block` to prevent public access.
* Added `create_daemon_certificate_request` variable to control whether CSRs should be created.

## 3.1.1 (2019-09-02)

* Use amazon-extras for epel.

## 3.1.0 (2019-09-02)

* Add support for putting in a symlink for the key and certificate files for the `daemon_private_key_pems`, `daemon_cert_pems` and `daemon_ca_cert_pem`.

## 3.0.0 (2019-07-13)

* Migrated to Terraform 0.12
