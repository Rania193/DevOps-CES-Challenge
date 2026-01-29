variable "project_name" {
  description = "Name of the project - used as prefix for all resources"
  type        = string
  default     = "datavisyn"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod) - affects resource naming and tagging"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner_email" {
  description = "Email of the person responsible for these resources - for tagging"
  type        = string
  default     = "devops@example.com"
}

# -----------------------------------------------------------------------------
# AWS REGION CONFIGURATION
# -----------------------------------------------------------------------------

variable "aws_region" {
  type        = string
  default     = "eu-west-1"
}

# -----------------------------------------------------------------------------
# NETWORKING VARIABLES
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = <<-EOT
    CIDR block for the VPC. This defines the IP address range for your network.
    
    CIDR notation: X.X.X.X/Y where Y is the subnet mask
    /16 = 65,536 IP addresses (10.0.0.0 - 10.0.255.255)
    /20 = 4,096 IP addresses
    /24 = 256 IP addresses
    
    For EKS, you need enough IPs for:
    - Worker nodes
    - Pods (EKS uses VPC CNI, so each pod gets a VPC IP)
    - Load balancers
    
    10.0.0.0/16 is a safe default that gives you plenty of room.
  EOT
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

# -----------------------------------------------------------------------------
# EKS CLUSTER VARIABLES
# -----------------------------------------------------------------------------

variable "cluster_version" {
  description = <<-EOT
    Kubernetes version for the EKS cluster.
    
    AWS supports the last 3-4 versions. Check AWS docs for current supported versions.
    Each version has a ~14 month support window.
    
    Tip: Don't use the absolute latest version in production - let others find bugs first!
  EOT
  type        = string
  default     = "1.28"
  
  validation {
    condition     = can(regex("^1\\.(2[5-9]|3[0-9])$", var.cluster_version))
    error_message = "Cluster version must be a valid EKS version (1.25-1.39)."
  }
}

variable "node_instance_types" {
  description = <<-EOT
    EC2 instance types for the EKS worker nodes.
    
    Considerations:
    - t3.medium: Good for dev/testing (2 vCPU, 4GB RAM) ~$30/month
    - t3.large: Good balance (2 vCPU, 8GB RAM) ~$60/month
    - m5.large: Production workloads (2 vCPU, 8GB RAM) ~$70/month
    - m5.xlarge: Heavier workloads (4 vCPU, 16GB RAM) ~$140/month
    
    Multiple types allow the autoscaler to find available capacity.
  EOT
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes - the autoscaler will try to maintain this"
  type        = number
  default     = 2
  
  validation {
    condition     = var.node_desired_size >= 1
    error_message = "Desired node size must be at least 1."
  }
}

variable "node_min_size" {
  description = "Minimum number of worker nodes - autoscaler won't go below this"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes - autoscaler won't exceed this"
  type        = number
  default     = 4
}

# -----------------------------------------------------------------------------
# TAGS
# -----------------------------------------------------------------------------

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
