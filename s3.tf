locals {
  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${local.dns_name}.terraform"
}

data "aws_iam_policy_document" "s3-access-role-policy" {
  count = var.store_join_tokens_as_tags ? 0 : 1
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.terraform[count.index].arn,
      "${aws_s3_bucket.terraform[count.index].arn}/*",
    ]
  }
}

resource "aws_s3_bucket" "terraform" {
  count         = var.store_join_tokens_as_tags ? 0 : 1
  bucket        = local.s3_bucket_name
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    transition {
      days          = 30
      storage_class = "ONEZONE_IA"
    }
  }

  tags = {
    Name = "${var.name} Swarm"
  }
}

resource "aws_iam_policy" "s3-access-role-policy" {
  count  = var.store_join_tokens_as_tags ? 0 : 1
  name   = "${local.dns_name}-s3-ec2-policy"
  policy = data.aws_iam_policy_document.s3-access-role-policy[count.index].json
}

resource "aws_iam_role_policy_attachment" "s3-access-role-policy" {
  count      = var.store_join_tokens_as_tags ? 0 : 1
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3-access-role-policy[count.index].arn
}

resource "aws_s3_bucket_public_access_block" "terraform" {
  count = var.store_join_tokens_as_tags ? 0 : 1
  depends_on = [
    aws_s3_bucket.terraform
  ]
  bucket = aws_s3_bucket.terraform[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
