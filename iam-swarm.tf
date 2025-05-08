# This TF fragment contains data and resources related to IAM that are global to the swarm after the instances have been created.

data "aws_iam_policy_document" "swarm-access-role-runtime-policy" {
  # This policy is for runtime not just creation time.
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeIamInstanceProfileAssociations",
      "ssm:UpdateInstanceInformation"
    ]

    resources = concat(
      aws_instance.managers[*].arn,
      aws_instance.workers[*].arn,
    )
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.dns_name}:log-stream:*"]
  }

  statement {
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = concat(
      aws_instance.managers[*].arn,
      aws_instance.workers[*].arn,
    )
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values = [
        "ManagerJoinToken",
        "WorkerJoinToken",
      ]
    }
  }
}

resource "aws_iam_policy" "swarm-access-role-runtime-policy" {
  name   = "${local.dns_name}-swarm-ec2-runtime-policy"
  policy = data.aws_iam_policy_document.swarm-access-role-runtime-policy.json
}

resource "aws_iam_role_policy_attachment" "swarm-access-role-runtime-policy" {
  # policies specific for the managers at run time. At this point the policy attachment
  # can contain specific instance resources.
  policy_arn = aws_iam_policy.swarm-access-role-runtime-policy.arn
  role       = aws_iam_role.ec2.name
}

data "aws_iam_policy_document" "deny-put-log-events" {
  statement {
    effect    = "Deny"
    actions   = ["logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deny-put-log-events" {
  name   = "${local.dns_name}-deny-put-log-events"
  policy = data.aws_iam_policy_document.deny-put-log-events.json
}

resource "aws_iam_role_policy_attachment" "deny-put-log-events" {
  count      = var.disable_cloudwatch_logs ? 1 : 0
  policy_arn = aws_iam_policy.deny-put-log-events.arn
  role       = aws_iam_role.ec2.name
}

data "aws_iam_policy_document" "deny-metric-events" {
  statement {
    effect    = "Deny"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deny-metric-events" {
  name   = "${local.dns_name}-deny-metric-events"
  policy = data.aws_iam_policy_document.deny-metric-events.json
}

resource "aws_iam_role_policy_attachment" "deny-metric-events" {
  count      = var.disable_cloudwatch_metrics ? 1 : 0
  policy_arn = aws_iam_policy.deny-metric-events.arn
  role       = aws_iam_role.ec2.name
}
