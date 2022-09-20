variable "name" {
  description = "Name of the swarm.  Note this has to be globally unique."
}

variable "ssh_key" {
  description = "SSH key to access the server."
}

variable "repo_url" {
  description = "URL to the proxy repo.  We are using Nexus so the URL is something like https://repo.trajano.net/repository/yum-group/.  Note trailing slash at the end."
  default     = ""
}

variable "repo_username" {
  description = "Username for the repo."
  default     = ""
}

variable "repo_password" {
  description = "Password for the repo."
  default     = ""
}

variable "managers" {
  description = "Number of managers in the swarm.  This should be an odd number otherwise there may be issues with raft consensus."
  default     = 1
}

variable "workers" {
  description = "Number of workers in the swarm."
  default     = 0
}

variable "instance_type" {
  description = "EC2 instance type."
  default     = "t3a.nano"
}

variable "access_key" {
  description = "AWS Access Key"
  default     = ""
}
variable "secret_key" {
  description = "AWS Secret Key"
  default     = ""
}
