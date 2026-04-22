# bootstrap/modules/oidc_provider/outputs.tf

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider — passed to the github_actions_role module"
  value       = aws_iam_openid_connect_provider.github.arn
}