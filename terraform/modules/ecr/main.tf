# terraform/modules/ecr/main.tf

# -------------------------------------------------------------------
# ECR REPOSITORIES
# One for frontend, one for backend.
# Using for_each so adding a new service = one line in variables.
# -------------------------------------------------------------------
resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repositories)

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"    # allows overwriting tags (needed for SHA tagging workflow)

  # Scan every image on push — free vulnerability scanning
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt images at rest using AWS-managed keys
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${each.key}-ecr"
  }
}

# -------------------------------------------------------------------
# LIFECYCLE POLICY — keep only the last N images per repo
# Prevents unbounded ECR storage costs over time
# -------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.image_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}