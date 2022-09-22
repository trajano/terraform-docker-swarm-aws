resource "aws_ssm_parameter" "cloudwatch-agent" {
  count = var.cloudwatch_agent_parameter == "" ? 1 : 0
  name  = "AmazonCloudWatch-${local.dns_name}"
  type  = "String"
  insecure_value = jsonencode({
    "agent" : {
      "run_as_user" : "cwagent",
      "quiet": true
    },
    "metrics" : {
      "aggregation_dimensions" : [
        [
          "InstanceId"
        ]
      ],
      "append_dimensions" : {
        "InstanceId" : "$${aws:InstanceId}",
      },
      "metrics_collected" : {
        "disk" : {
          "measurement" : [
            "used_percent",
            "used",
            "free"
          ],
          "metrics_collection_interval" : 60,
          "resources" : [
            "*"
          ]
        },
        "mem" : {
          "measurement" : [
            "used_percent",
            "used",
            "free"
          ],
          "metrics_collection_interval" : 60
        },
        "swap" : {
          "measurement" : [
            "free",
            "used_percent"
          ],
          "metrics_collection_interval" : 60
        }
      }
    }
  })
}

locals {
  cloudwatch_agent_parameter = var.cloudwatch_agent_parameter == "" ? aws_ssm_parameter.cloudwatch-agent[0].name : var.cloudwatch_agent_parameter
}
