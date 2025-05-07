variable "name" {
  description = "Specifies the name of the swarm that is going to be built.  It is used for names and DNS names."
  type        = string
}

variable "managers" {
  description = "Number of managers in the swarm.  This should be an odd number otherwise there may be issues with raft consensus."
  default     = 3
  type        = number
  validation {
    condition     = var.managers % 2 == 1
    error_message = "The number of managers must be an odd number."
  }
  validation {
    condition     = var.managers > 0
    error_message = "The number of managers must be greater than 0."
  }

}

variable "workers" {
  description = "Number of workers in the swarm."
  default     = 0
  validation {
    condition     = var.workers > 0
    error_message = "The number of managers must be greater than or equal to 0."
  }
  type = number
}

variable "ami_name_regex" {
  description = "Name regex for the AMI to use.  This must be an Amazon Linux on or after Amazon Linux 2023. `ARCH` is replaced with the architecture"
  default     = "^al2023-ami-2023.*-.*-ARCH"
  type        = string
}
variable "detailed_monitoring" {
  description = "Detailed instance monitoring"
  default     = false
  type        = bool
}

variable "metadata_http_tokens_required" {
  description = "Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2 (IMDSv2)."
  default     = false
  type        = bool
}

variable "metadata_put_response_hop_limit" {
  description = "Desired HTTP PUT response hop limit for instance metadata requests. The larger the number, the further instance metadata requests can travel. Valid values are integer from 1 to 64."
  default     = 2
  type        = number
}

variable "vpc_id" {
  description = "The VPC that will contain the swarm."
  type        = string
}

variable "associate_public_ip_address" {
  description = "This makes the manager and worker nodes accessible from the Internet."
  default     = true
  type        = bool
}

variable "cloud_config_extra" {
  description = "Content added to the end of the cloud-config file."
  default     = ""
  type        = string
}

variable "cloud_config_extra_merge_type" {
  description = "Merge type to apply to cloud config."
  default     = "list()+dict()+str()"
  type        = string
}

variable "cloud_config_extra_script" {
  description = "Shell script that will be executed on every node.  This can be used to set up EFS mounts in fstab or do node specific bootstrapping. This is executed after `init_manager.py`"
  default     = ""
  type        = string

}

variable "cloudwatch_logs" {
  description = "Enables logging to Cloudwatch."
  default     = false
  type        = bool
}

variable "cloudwatch_agent_parameter" {
  description = "Provides an override to the metrics that are going to be sent by the cloudwatch agent."
  default     = ""
  type        = string
}

variable "cloudwatch_kms_key_id" {
  description = "KMS key ID for Cloudwatch log encryption."
  default     = ""
  type        = string
}

variable "cloudwatch_single_log_group" {
  description = "Creates a single log group for the whole swarm rather than one per node."
  default     = false
  type        = bool
}

variable "cloudwatch_retention_in_days" {
  description = "Specifies the number of days you want to retain log events in the specified log group. Possible values are: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653. 0 means never expire."
  type        = number
  default     = 0

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653],
      var.cloudwatch_retention_in_days
    )
    error_message = "cloudwatch_retention_in_days must be one of the allowed retention values."
  }
}


variable "additional_security_group_ids" {
  description = "These are security groups that are applied to the Docker swarm nodes primarily for accessing other resources or exposing to the Internet."
  type        = list(string)
  default     = []
}

variable "additional_alarm_actions" {
  description = "These are ARNs to alarm actions that will be appended to the one created by the module."
  type        = list(string)
  default     = []
}

variable "exposed_security_group_ids" {
  description = "These are security groups that are applied to the Docker swarm nodes primarily for accessing other resources or exposing to the Internet. The variable name is kept for legacy reasons, use `additional_security_group_ids`"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type.  This is can be overriden by `instance_type_manager` or `instance_type_worker`"
  default     = "t3.micro"
  type        = string
}

variable "instance_type_manager" {
  description = "Manager node EC2 instance type.  If not specified it will use the value of `instance_type`."
  default     = ""
  type        = string
}

variable "instance_type_worker" {
  description = "Worker node EC2 instance type.  If not specified it will use the value of `instance_type`"
  default     = ""
  type        = string
}
variable "volume_size" {
  description = "Size of root volume in gigabytes.  Minimum size is 30GB."
  default     = 30
  type        = number
  validation {
    condition     = var.volume_size >= 30
    error_message = "The root volume size must be at least 30GB."
  }
}

variable "swap_size" {
  description = "Size of swap drive in gigabytes."
  default     = 1
  type        = number
}

variable "manager_subnet_segment_start" {
  description = "This is added to the index to represent the third segment of the IP address."
  default     = 10
  type        = number
}

variable "worker_subnet_segment_start" {
  description = "This is added to the index to represent the third segment of the IP address."
  default     = 110
  type        = number
}

variable "key_name" {
  description = "The key name of the Key Pair to use for the instance; which can be managed using the aws_key_pair resource.  This is used for SSH access to the instance via the default user of the AMI (e.g. `ec2-user`) during setup, once the cloud-init completes the key will no longer be used"
  default     = ""
  type        = string
}




variable "excluded_availability_zones" {
  description = "List of availability zones to exclude from the computation."
  type        = list(string)
  default     = []
}

variable "ssh_authorization_method" {
  description = "Authorization method for SSH. This is one of `none`, `ec2-instance-connect`, `iam` (default)."
  type        = string
  default     = "iam"

  validation {
    condition     = contains(["none", "ec2-instance-connect", "iam"], var.ssh_authorization_method)
    error_message = "ssh_authorization_method must be one of: 'none', 'ec2-instance-connect', or 'iam'."
  }
}

variable "ssh_users" {
  description = "A list of IAM users that will have SSH access when using `iam` for `ssh_authorization_method`"
  default     = []
  type        = list(string)
}

variable "generate_host_keys" {
  description = "If true, the host keys are generated by the module.  Only do this if access to the state store is secure."
  default     = true
  type        = bool
}

variable "sns_kms_id" {
  description = "The ID of an AWS-managed customer master key (CMK) for Amazon SNS or a custom CMK for SNS use."
  default     = ""
  type        = string
}

variable "extra_tags" {
  description = "Extra tags to add to the resources created by this module. This can be used with cost explorer."
  type        = map(string)
  default     = {}
}

variable "map_public_ip_on_launch" {
  description = "Enabling this boolean will set automatic public ip assignment on the worker and manager subnets"
  default     = true
  type        = bool
}
