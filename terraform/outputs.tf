# terraform/outputs.tf

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Use in: aws eks update-kubeconfig --name <value>"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  description = "ECR repository URLs — paste into GitHub Secrets as ECR_REGISTRY"
  value       = module.ecr.repository_urls
}

output "alb_controller_role_arn" {
  description = "Passed to bootstrap.sh to annotate the ALB controller service account"
  value       = module.eks.alb_controller_role_arn
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "next_steps" {
  value = <<-EOT

    Infrastructure ready. Now run:

    1. Run the bootstrap script — sets up in-cluster components:
       cd ~/cloudnative-task-manager
       ./scripts/bootstrap.sh

    2. Verify everything is healthy:
       kubectl get nodes
       kubectl get pods -n kube-system
       kubectl top nodes

    3. Move to k8s/ and start applying manifests.

  EOT
}