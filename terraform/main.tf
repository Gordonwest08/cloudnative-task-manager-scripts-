# terraform/main.tf

data "aws_caller_identity" "current" {}

# -------------------------------------------------------------------
# MODULE: VPC
# -------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# -------------------------------------------------------------------
# MODULE: ECR
# -------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}

# -------------------------------------------------------------------
# MODULE: EKS
# -------------------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  project_name            = var.project_name
  environment             = var.environment
  cluster_version         = var.cluster_version
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_instance_type      = var.node_instance_type
  node_desired_size       = var.node_desired_size
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  github_actions_role_arn = var.github_actions_role_arn
}