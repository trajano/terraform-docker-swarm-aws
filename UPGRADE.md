# Upgrade notes

## AWS provider 4.x to 6.x

Module 6.1.x requires AWS provider 6.63.0 or later within the 6.x series.
These provider versions are separate from the module versions below.

* Follow HashiCorp's [version 5 upgrade guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-5-upgrade) and [version 6 upgrade guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-6-upgrade). Before switching to this module version, use the previous module version to check a plan with the latest 4.x provider, then the latest 5.x provider. Resolve errors, deprecation warnings, and unexpected changes at each stage.
* In the deployment's root configuration, select AWS provider `6.63.0` to reproduce the version validated for this upgrade. Run `terraform init -upgrade` and review the dependency lock file, since this command can also upgrade other providers and modules.
* Replace `aws_eip`'s removed `vpc = true` argument with `domain = "vpc"` in caller configurations. The examples include this change.
* Replace `data.aws_region.current.name` with `data.aws_region.current.region`. The module includes this change for IAM policies, instance bootstrap data, and the CloudWatch dashboard.
* The module already supplies `owners` for its most-recent AMI lookup and uses `user_data_base64` for EC2 bootstrap data. These meet the corresponding version 6 migration requirements.
* Run `terraform validate`, then review a normal `terraform plan` against the deployment's existing state. Check instance replacements, network changes, tags, and IAM policies before applying. Local validation does not verify state migration or AWS API behavior.

## 3.x to 4.x

* Do not enable `store_join_tokens_as_tags` as that will corrupt the cluster.
* `daemon_ssh=false` and `daemon_tls=true` will keep the same behaviour, but it is recommended that the defaults are used for for new clusters.

## 4.0.x to 4.1.x

* If packages are customized, `haveged` is now required.

## 4.x to 5.x

FYI at time of this writing, it is NOT recommended that users upgrade to 5.x unless they need to due to usability bugs in Terraform and the AWS provider.  Workarounds are provided to known issues.  It is best to wait for 0.13.1
* Terraform 0.13 is now required.  Perform a `terraform 0.13ugprade` and `terraform init -upgrade` to update your Terraform files before using.
* [`aws_availability_zones` will always have a diff](https://github.com/terraform-providers/terraform-provider-aws/issues/14579)
* `terraform state replace-provider -- -/aws hashicorp/aws` generally helps address existing state issues [terraform#25819](https://github.com/hashicorp/terraform/issues/25819#issuecomment-672939811)
* [State files may need to be modified using pull and push](https://github.com/hashicorp/terraform/issues/25752#issuecomment-672217777) to [remove resource state attributes that are no longer in the schema that was fixed for 0.13.1](https://github.com/hashicorp/terraform/issues/25752#issuecomment-672217777)

## 5.x to 6.x

* Remove `store_join_tokens_as_tags`, the setting is no longer supported
* Remove `daemon_count`, the setting is no longer supported
