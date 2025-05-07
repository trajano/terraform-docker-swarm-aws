
terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.0.0, < 3.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.3, < 5.0.0"
    }
  }
}
