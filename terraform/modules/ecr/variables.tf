# terraform/modules/ecr/variables.tf

variable "project_name" {
  type = string
}

variable "repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["frontend", "backend"]
}

variable "image_retention_count" {
  description = "Number of images to keep per repository — older ones are deleted automatically"
  type        = number
  default     = 10
}