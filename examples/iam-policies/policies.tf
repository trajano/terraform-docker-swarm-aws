provider "aws" {
  region = "us-east-1"
}

locals {
  policies = [
    "terraform-dockerswarm-cloudwatch",
    "terraform-dockerswarm-ec2-any",
    "terraform-dockerswarm-ec2-resource",
    "terraform-dockerswarm-iam",
  ]
}
resource "aws_iam_policy" "terraform-dockerswarm" {
  count       = length(local.policies)
  name        = local.policies[count.index]
  description = "Policy allowing Terraforming resources using the terraform-docker-swarm-aws module"
  path        = "/terraform/"
  policy      = file("${local.policies[count.index]}.json")
}

resource "aws_iam_group" "terraform-dockerswarm" {
  name = "terraform-dockerswarm"
  path = "/terraform/"
}

resource "aws_iam_group_policy_attachment" "terraform-dockerswarm" {
  count      = length(local.policies)
  group      = aws_iam_group.terraform-dockerswarm.name
  policy_arn = aws_iam_policy.terraform-dockerswarm[count.index].arn
}

terraform {
  required_version = ">= 0.12"
}
