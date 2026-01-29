terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"  # Download from HashiCorp's registry
      version = "~> 5.0"         # Use version 5.x
    }
  }
}