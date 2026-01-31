output "cluster_name" {
  description = "Name of the EKS cluster - use this with kubectl and aws eks commands"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint URL for the EKS API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (where worker nodes run)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets (where load balancers are created)"
  value       = module.vpc.public_subnet_ids
}

output "cluster_ca_certificate" {
  description = "Base64 encoded CA certificate for the cluster"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true  # Don't print in logs
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA (IAM Roles for Service Accounts)"
  value       = module.eks.oidc_provider_arn
}

# helper outputs
output "configure_kubectl" {
  description = "Command to configure kubectl to connect to this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "region" {
  description = "AWS region where the cluster is deployed"
  value       = var.aws_region
}

# NLB Elastic IP - use for static IP load balancer
output "nlb_eip_allocation_id" {
  description = "Elastic IP allocation ID for NLB - add to ingress-nginx.yaml"
  value       = module.vpc.nlb_eip_id
}

output "nlb_eip_public_ip" {
  description = "Static public IP for your load balancer - use in DuckDNS"
  value       = module.vpc.nlb_eip_ip
}

output "nlb_subnet_id" {
  description = "Public subnet ID for single-AZ NLB - add to ingress-nginx.yaml"
  value       = module.vpc.public_subnet_ids[0]
}

# ECR outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository for webapp images"
  value       = module.ecr.webapp_repository_url
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions (add to GitHub Secrets as AWS_ROLE_ARN)"
  value       = var.github_repo != "" ? module.iam.github_actions_role_arn : ""
}

output "alb_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.iam.alb_controller_role_arn
}
