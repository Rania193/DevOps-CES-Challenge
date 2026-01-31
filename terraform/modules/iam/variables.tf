variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https://)"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo (e.g., Rania193/DevOps-CES-Challenge)"
  type        = string
  default     = ""
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository for GitHub Actions to push images"
  type        = string
  default     = ""
}
