variable "name" {
  description = "Name of the swarm.  Note this has to be globally unique."
  type        = string
}

variable "ssh_key" {
  description = "SSH key to access the server."
  type        = string
}

variable "managers" {
  description = "Number of managers in the swarm.  This should be an odd number otherwise there may be issues with raft consensus."
  default     = 1
  type        = string
}

variable "workers" {
  description = "Number of workers in the swarm."
  default     = 0
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  default     = "t3a.micro"
  type        = string
}

variable "access_key" {
  description = "AWS Access Key"
  default     = ""
  type        = string
}
variable "secret_key" {
  description = "AWS Secret Key"
  default     = ""
  type        = string
}
