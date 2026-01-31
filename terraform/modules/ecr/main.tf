# ECR Repository for webapp Docker images
resource "aws_ecr_repository" "webapp" {
  name                 = "webapp"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "webapp"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Lifecycle policy to keep only last 10 images
resource "aws_ecr_lifecycle_policy" "webapp" {
  repository = aws_ecr_repository.webapp.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

