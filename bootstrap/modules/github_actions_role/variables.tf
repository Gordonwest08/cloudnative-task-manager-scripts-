# bootstrap/modules/github_actions_role/variables.tf

variable "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider (output from oidc_provider module)"
  type        = string
}

variable "github_org" {
  description = "Your GitHub username or organisation name"
  type        = string
}

variable "github_repo" {
  description = "Repository name (without the org prefix)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources live"
  type        = string
}

variable "aws_account_id" {
  description = "Your 12-digit AWS account ID"
  type        = string
}

variable "project_name" {
  description = "Project name used in resource names and ARN scoping"
  type        = string
}