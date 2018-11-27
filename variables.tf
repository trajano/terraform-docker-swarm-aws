variable "name" {
  description = "Specifies the name of the swarm that is going to be built.  It is used for names and DNS names."
}

variable "managers" {
  description = "Number of managers in the swarm.  This should be an odd number otherwise there may be issues with raft consensus."
  default     = 3
}

variable "workers" {
  description = "Number of workers in the swarm."
  default     = 0
}

variable "vpc_id" {
  description = "The VPC that will contain the swarm."
}

variable "cloud_config_extra" {
  description = "Content added to the end of the cloud-config file."
  default     = ""
}

variable "exposed_security_group_ids" {
  description = "This is the security group ID that specifies the ports that would be exposed by the swarm for external access."
  type        = "list"
}

variable "s3_bucket_name" {
  description = "The S3 bucket name, if not specified it will be the DNS name with .terraform added to the end."
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Size of root volume in gigabytes."
  default     = 8
}

variable "manager_subnet_segment_start" {
  description = "This is added to the index to represent the third segment of the IP address."
  default     = 10
}

variable "worker_subnet_segment_start" {
  description = "This is added to the index to represent the third segment of the IP address."
  default     = 110
}

variable "key_name" {
  description = "The key name of the Key Pair to use for the instance; which can be managed using the aws_key_pair resource."
  default     = ""
}

variable "daemon_count" {
  description = "This is the number of manager EIPs.  This is a workaround as count in some contexts cannot be a computed value."
  default     = 0
}

variable "daemon_eip_ids" {
  description = "These are elastic IP association IDs that will be attached to the manager nodes.  The attachment occurs as part of the module."
  type        = "list"
  default     = []
}

variable "daemon_private_key_pems" {
  description = "These are private key PEMs to the manager nodes that will have their Docker sockets exposed."
  type        = "list"
  default     = []
}

variable "daemon_cert_pems" {
  description = "These are cert PEMs to the manager nodes that will have their Docker sockets exposed."
  type        = "list"
  default     = []
}

variable "daemon_ca_cert_pem" {
  description = "This is the cert for the CA."
  default     = ""
}

variable "daemon_private_key_algorithm" {
  description = "The name of the algorithm for the key provided in manager_private_key_pems."
  default     = "RSA"
}

variable "daemon_dns" {
  description = "Public DNS names associated with the manager."
  type        = "list"
  default     = []
}
