# PROVIDERS
#____________________________________________________________
terraform {
  required_version = ">= 1.6.0"


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
      bucket       = "taskmanager-terraform-state550"
      key          = "bootstrap/terraform.tfstate"
      region       = "us-east-1"
      use_lockfile = true
      
  }

}



# -------------------------------------------------------------------
# REMOTE STATE — bootstrap has its OWN state file, separate from
# terraform/. This is intentional: the OIDC provider and IAM role
# are account-level infrastructure. A terraform destroy on the main
# stack must NEVER accidentally delete these.
# -------------------------------------------------------------------


provider "aws" {
  region = var.aws_region

}

# -------------------------------------------------------------------
# DATA SOURCE — fetch the current AWS account ID automatically.
# Avoids hardcoding the account ID anywhere in code.
# -------------------------------------------------------------------

data "aws_caller_identity" "current" {}


# -------------------------------------------------------------------
# MODULE 1 — OIDC PROVIDER
# Registers GitHub as a trusted identity provider in this AWS account.
# -------------------------------------------------------------------

module "oidc_provider" {
  source       = "./modules/oidc_provider"
  project_name = var.project_name
}

# -------------------------------------------------------------------
# MODULE 2 — GITHUB ACTIONS IAM ROLE
# Creates the role GitHub Actions will assume, with scoped permissions.
# Receives the OIDC provider ARN from module 1.
# -------------------------------------------------------------------
module "github_actions_role" {
  source = "./modules/github_actions_role"

  oidc_provider_arn = module.oidc_provider.oidc_provider_arn
  github_org        = var.github_org
  github_repo       = var.github_repo
  aws_region        = var.aws_region
  aws_account_id    = data.aws_caller_identity.current.account_id
  project_name      = var.project_name
}
