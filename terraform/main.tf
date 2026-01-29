terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"  # Download from HashiCorp's registry
      version = "~> 5.0"         # Use version 5.x
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "ces-challenge-terraform-state"
    key            = "ces-challenge/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "ces-challenge-terraform-lock"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
  
  # Exclude Local Zones (they have different capabilities)
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  name_prefix = "${var.project_name}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.azs
  environment        = var.environment
}

module "eks" {
  source = "./modules/eks"

  name_prefix         = local.name_prefix
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  environment = var.environment

  depends_on = [module.vpc]
}

module "iam" {
  source = "./modules/iam"
  name_prefix = local.name_prefix
  eks_oidc_provider_url = module.eks.oidc_provider_url
  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  
  depends_on = [module.eks]
}