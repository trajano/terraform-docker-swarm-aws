terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.3, < 5.0.0"
    }
  }
  required_version = ">= 0.13"
}
