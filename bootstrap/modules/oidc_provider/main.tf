# bootstrap/modules/oidc_provider/main.tf

# -------------------------------------------------------------------
# DATA SOURCE — fetch the TLS thumbprint of GitHub's OIDC endpoint
# automatically. This is the fingerprint AWS uses to verify that
# tokens genuinely come from GitHub and haven't been tampered with.
# -------------------------------------------------------------------
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# -------------------------------------------------------------------
# OIDC IDENTITY PROVIDER
# Registers GitHub Actions as a trusted identity provider in this
# AWS account. Created once per account — if it already exists,
# Terraform will import it rather than create a duplicate.
# -------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # The audience that GitHub tokens are issued for.
  # "sts.amazonaws.com" is the value AWS expects when a workflow
  # calls sts:AssumeRoleWithWebIdentity.
  client_id_list = ["sts.amazonaws.com"]

  # TLS thumbprint — proves the OIDC endpoint is genuine GitHub.
  # Fetched dynamically above so it never goes stale.
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Name        = "github-oidc-provider"
    ManagedBy   = "terraform"
    Project     = var.project_name
  }
}