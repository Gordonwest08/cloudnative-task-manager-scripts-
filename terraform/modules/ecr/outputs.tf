# terraform/modules/ecr/outputs.tf

output "repository_urls" {
  description = "Map of repository name to full ECR URL — used in CI/CD pipeline"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "registry_id" {
  description = "AWS account ID that owns the registry"
  value       = values(aws_ecr_repository.repos)[0].registry_id
}