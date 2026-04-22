variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"

}

variable "github_org" {
  description = "Your GitHub username or organisation (e.g. gordon-west)"
  type        = string
}

variable "github_repo" {
  description = "Repository name only, no org prefix (e.g. cloudnative-task-manager)"
  type        = string
}


variable "project_name" {
  description = "Short project identifier used in all resource names (e.g. taskmanager)"
  type        = string
  default     = "taskmanager"

}
