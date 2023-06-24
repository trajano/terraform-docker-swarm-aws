resource "aws_cloudwatch_dashboard" "main" {
  count          = (var.cloudwatch_dashboard && var.cloudwatch_logs && var.cloudwatch_single_log_group) ? 1 : 0
  dashboard_name = local.dns_name

  dashboard_body = jsonencode(
    yamldecode(
      templatefile("${path.module}/cloudwatch-dashboard.yaml.tftpl", {
        region         = data.aws_region.current.name,
        log_group_name = aws_cloudwatch_log_group.main[0].name,
        instance_ids = toset(flatten([
          aws_instance.managers.*.id,
          aws_instance.workers.*.id,
        ])),
        }
      )
    )
  )
}
