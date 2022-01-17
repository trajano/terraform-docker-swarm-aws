# Change Log

## 5.2.11

* Allow setting `docker_username` to execute the worker node removal scripts on destory of worker nodes.

## 5.2.10

* `vm.overcommit_memory=1` is to prevent [background saving issues with Redis](https://redis.io/topics/faq#background-saving-fails-with-a-fork-error-under-linux-even-if-i-have-a-lot-of-free-ram)

## 5.2.9

* Fix so that `manager0` will rejoin swarm if tainted.
* Updated Upgrade guide in README to explicitly indicate nodes.

## 5.2.8

* Fix to support non-burstable instances.

## 5.2.6

* Changed the `aws` provider to allow anything before `4.0.0` 
* Removed the `version` in the `aws` provider used in `examples`
* Created a version lock file in `sandbox` example 

## 5.2.5

* Added logStream to the dashboard logs
* Added support for additional_alarm_actions

## 5.2.4

* Fix issues when `ssh_authorization_method` is false

## 5.2.3

* Fix issues when `ssh_authorization_method` is false

## 5.2.2

* Fix issues with CloudWatch dashboard
* Fix issues when `ssh_authorization_method` is false

## 5.2.1

* Upgraded provider versions to current ones.  Major one was cloud-init which is now version 2.0.0 and set the upper bound for versions.
* `cloudwatch_retention_in_days` specifies that 0 is allowed for never expire and use that as the default.
* Fixed cycle in managers.tf preventing multiple managers from being created.
* Added a CloudWatch dashboard
* `AuthorizedKeysCommand` takes the same approach as GitHub and Azure Devops where login uses a single OS user with multiple authorized keys.

## 5.2.0

* `ec2-instance-connect` is deprecated in favor of a custom AuthorizedKeysCommand which is easier to manage since it's a matter of provisioning an IAM user account and uploading the SSH public key.  This is configurable through `ssh_authorization_method` which is one of `none`, `ec2-instance-connect` or `iam` and other value is equivalent to `none`.  This defaults to `ec2-instance-connect` for backwards compatibility until `6.0`.

## 5.1.4

* Mostly coding style issues.

## 5.1.3

* Fixed issue with `cloudwatch_single_log_group` in that the log group isn't created causing issues with the start up of services.

## 5.1.2

* Fixed issue with system metrics not coming up.

## 5.1.1

* `cloudwatch_single_log_group` (default `false`) creates a single log group for the whole swarm rather than one per node.  This will make use of [aws tail](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/logs/tail.html) work as it only supports a single log group.

## 5.1.0 Cloudwatching

This release includes support for more Cloudwatch functions.

* `cloudwatch_logs` enables containers to log to CloudWatch.  Note if this is enabled, then logs will not be available when SSH to the server.  This is disabled by default.
* Networks are no longer pruned daily.  They don't take up much space unlike volumes and images.
* Added [monitoring EC2 instance scripts](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html).

## 5.0.0

* Terraform 0.13 is now required.
* AWS 3.3 required

## 4.1.2

* Commented out the `source` in the [provider version constraints](https://www.terraform.io/docs/configuration/modules.html#provider-version-constraints-in-modules).  These require Terraform 0.13 to work.
* Set the constraints to allow AWS 3.x as well since they are compatible.
* Expose private IPs to allow use with Security Groups.

## 4.1.1

* Use [provider version constraints][https://www.terraform.io/docs/configuration/modules.html#provider-version-constraints-in-modules]

## 4.1.0

* Made `haveged` and `yum-cron` packages optional.
* Install the `haveged` package to provide better entropy.
* Install the `ec2-instance-connect` package to provide IAM based logins.

## 4.0.5

* Added `[]` as default value for `exposed_security_group_ids` but noted that this is deprecated.
* Added `[]` as default value for `additional_security_group_ids`.
* Added `root/bin/add-docker-user.sh` to help add additional users to use `docker context`.

## 4.0.4

* Corrected host name for workers

## 4.0.3

* When `store_join_tokens_as_tags`, S3 resources are no longer created.  The S3 specific code had also been refactored out to `s3.tf`
* Fixed an error in cloud config that prevented ulimits from being set.

## 4.0.2

* Bugfix in script

## 4.0.1

* Allow using Instance Tags to store the join tokens instead of S3.  This is not the default.  Instance tags are used because VPCs are set outside of the module.  Note this should not be used on an existing system as the cluster will be invalidated.
* Allow policy version updates in the terraform IAM policies
* Compute region name from instance metadata
* (fixed) all instances were going to the same availability zone.  To prevent recreating the instances these changes are ignored in the lifecycle.

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
