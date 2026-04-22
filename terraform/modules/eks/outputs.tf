# terraform/modules/eks/outputs.tf

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64-encoded certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "node_group_role_arn" {
  description = "IAM role ARN of the node group"
  value       = aws_iam_role.node_group.arn
}

output "alb_controller_role_arn" {
  description = "ALB controller IAM role ARN — used in bootstrap.sh service account annotation"
  value       = aws_iam_role.alb_controller.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — useful for adding more IRSA roles later"
  value       = aws_iam_openid_connect_provider.cluster.arn
}