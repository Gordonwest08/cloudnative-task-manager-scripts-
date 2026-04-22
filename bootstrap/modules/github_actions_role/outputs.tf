# bootstrap/modules/github_actions_role/outputs.tf

output "role_arn" {
  description = "The ARN of the GitHub Actions IAM role — paste this into GitHub Secrets as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "The name of the IAM role"
  value       = aws_iam_role.github_actions.name
}