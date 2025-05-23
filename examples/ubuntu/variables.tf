variable "name" {
  description = "The name of the Docker Swarm cluster to be created. This value will be used for naming and DNS purposes."
  type        = string
}

variable "managers" {
  description = "The number of manager nodes in the Swarm cluster. This should be an odd number to ensure proper Raft consensus."
  default     = 1
  type        = number
}

variable "detailed_monitoring" {
  description = "Enables detailed monitoring for EC2 instances."
  default     = false
  type        = bool
}

variable "metadata_http_tokens_required" {
  description = "Specifies whether the instance metadata service requires session tokens (IMDSv2)."
  default     = false
  type        = bool
}

# variable "vpc_id" {
#   description = "The ID of the VPC where the Swarm cluster will be deployed."
#   type        = string
# }

variable "associate_public_ip_address" {
  description = "Determines if manager and worker nodes should have public IP addresses for internet access."
  default     = true
  type        = bool
}

variable "cloud_config_extra_merge_type" {
  description = "Specifies the merge strategy used for cloud-init configuration."
  default     = "list()+dict()+str()"
  type        = string
}

variable "cloudwatch_logs" {
  description = "Indicates whether to enable logging to Amazon CloudWatch Logs."
  default     = false
  type        = bool
}

variable "cloudwatch_agent_parameter" {
  description = "Overrides the default CloudWatch Agent configuration for metrics collection."
  default     = ""
  type        = string
}

variable "cloudwatch_single_log_group" {
  description = "If true, creates a single CloudWatch log group for the entire Swarm instead of one per node."
  default     = false
  type        = bool
}

variable "cloudwatch_retention_in_days" {
  description = "Number of days to retain CloudWatch Logs. Accepted values are: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653. 0 indicates logs never expire."
  default     = 0
  type        = number
}

variable "additional_alarm_actions" {
  description = "A list of ARNs for additional alarm actions to be added to those created by the module."
  type        = list(string)
  default     = []
}

variable "exposed_security_group_ids" {
  description = "Security groups applied to Swarm nodes for external access or resource interaction. This is retained for legacy support; consider using `additional_security_group_ids`."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "Default EC2 instance type for Swarm nodes, overridden by `instance_type_manager` or `instance_type_worker`."
  default     = "t3a.medium"
  type        = string
}

variable "instance_type_manager" {
  description = "EC2 instance type for manager nodes. Falls back to `instance_type` if unspecified."
  default     = ""
  type        = string
}

variable "volume_size" {
  description = "Size of the root volume for each instance in gigabytes."
  default     = 8
  type        = number
}

variable "swap_size" {
  description = "Size of the swap file in gigabytes. This must be smaller than the root volume size."
  default     = 1
  type        = number
}

variable "manager_subnet_segment_start" {
  description = "Starting value for the third segment in manager node IP subnet addresses."
  default     = 10
  type        = number
}

variable "worker_subnet_segment_start" {
  description = "Starting value for the third segment in worker node IP subnet addresses."
  default     = 110
  type        = number
}

variable "key_name" {
  description = "The name of the SSH key pair used for accessing EC2 instances."
  default     = ""
  type        = string
}

variable "excluded_availability_zones" {
  description = "List of availability zones to exclude during resource allocation."
  type        = list(string)
  default     = []
}

variable "ssh_authorization_method" {
  description = "SSH authorization method. Valid values are: `none`, `ec2-instance-connect`, or `iam`."
  default     = "iam"
  type        = string
}

variable "ssh_users" {
  description = "List of IAM users granted SSH access when using `iam` for SSH authorization."
  default     = []
  type        = list(string)
}

variable "generate_host_keys" {
  description = "If true, host SSH keys are generated by the module. Enable only if state store access is secured."
  default     = true
  type        = bool
}

variable "sns_kms_id" {
  description = "The KMS key ID for encrypting SNS messages. Supports both AWS-managed and custom keys."
  default     = ""
  type        = string
}

variable "ssh_key" {
  description = "The SSH public key used for accessing the server."
  type        = string
}

variable "ami_name_regex" {
  description = "Regular expression used to identify the desired AMI. Supports placeholders like `ARCH` for architecture. Must match Amazon Linux 2023 or later."
  default     = "^ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-.*"
  type        = string
  # default  = "^al2023-ami-2023.*-.*-ARCH"
}
