# bootstrap/outputs.tf

output "github_actions_role_arn" {
  description = "Paste this into GitHub → Settings → Secrets → AWS_ROLE_ARN"
  value       = module.github_actions_role.role_arn
}

output "github_actions_role_name" {
  description = "IAM role name — useful for referencing in EKS access entries"
  value       = module.github_actions_role.role_name
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN — may be needed by main terraform module"
  value       = module.oidc_provider.oidc_provider_arn
}

output "next_steps" {
  description = "What to do after this apply"
  value       = <<-EOT
    Bootstrap complete. Now do the following:

    1. Copy the role ARN above into GitHub:
       Repo → Settings → Secrets and variables → Actions
       Secret name : AWS_ROLE_ARN
       Secret value: ${module.github_actions_role.role_arn}

    2. Add these three secrets in the same place:
       AWS_REGION       = ${var.aws_region}
       ECR_REGISTRY     = <your-account-id>.dkr.ecr.${var.aws_region}.amazonaws.com
       EKS_CLUSTER_NAME = ${var.project_name}-cluster

    3. Move to terraform/ and run the main infrastructure.
  EOT
}