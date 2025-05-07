# This TF fragment contains data and resources related to IAM that are global to the swarm after the instances have been created.

data "aws_iam_policy_document" "deny-put-log-events" {
  statement {
    effect  = "Deny"
    actions = ["logs:PutLogEvents"]
    resources = concat(
      aws_instance.managers[*].arn,
      aws_instance.workers[*].arn,
    )
  }
}

resource "aws_iam_policy" "deny-put-log-events" {
  name   = "${local.dns_name}-deny-put-log-events"
  policy = data.aws_iam_policy_document.deny-put-log-events.json
}

resource "aws_iam_role_policy_attachment" "deny-put-log-events" {
  count = var.disable_cloudwatch_logs ? 1 : 0
  # policies specific for the managers at run time. At this point the policy attachment
  # can contain specific instance resources.
  policy_arn = aws_iam_policy.deny-put-log-events.arn
  role       = aws_iam_role.ec2.name
}
