output "webapp_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.webapp.repository_url
}

output "webapp_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.webapp.arn
}

output "webapp_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.webapp.name
}

