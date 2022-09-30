# Upgrade notes

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
* Regenerate the dashboard by tainting it e.g., `terraform taint module.docker-swarm.aws_cloudwatch_dashboard.main[0]`.
