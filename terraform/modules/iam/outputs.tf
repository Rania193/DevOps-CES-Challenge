output "alb_controller_role_arn" {
  description = "ARN of the ALB controller IAM role"
  value       = aws_iam_role.alb_controller.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = var.github_repo != "" && var.ecr_repository_arn != "" ? aws_iam_role.github_actions[0].arn : ""
}
