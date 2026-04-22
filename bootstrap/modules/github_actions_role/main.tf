# bootstrap/modules/github_actions_role/main.tf

# -------------------------------------------------------------------
# TRUST POLICY — who is allowed to assume this role
#
# The condition is the critical security control. It locks the role
# to ONLY your specific GitHub repo AND only the main branch.
# Without the condition, any GitHub Actions workflow anywhere in the
# world could assume this role if they knew its ARN.
# -------------------------------------------------------------------
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "GitHubOIDCTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # This condition is the security boundary.
    # Only THIS repo on THIS branch can assume the role.
    # Format: repo:<org-or-username>/<repo-name>:ref:refs/heads/<branch>
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

# -------------------------------------------------------------------
# PERMISSION POLICY — what the role is allowed to do
#
# Principle of least privilege: only the exact permissions the
# CI/CD pipeline needs, nothing more.
#
#   ECR  → push and pull container images
#   EKS  → read cluster config to build kubeconfig
#   STS  → verify own identity (used by aws-actions in the workflow)
# -------------------------------------------------------------------
data "aws_iam_policy_document" "github_actions_permissions" {
  # --- ECR: authenticate and push images ---
  statement {
    sid    = "ECRAuthentication"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"           # docker login to ECR
    ]
    resources = ["*"]                        # this action cannot be scoped to a resource
  }

  statement {
    sid    = "ECRImagePush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",    # check if layers already exist
      "ecr:InitiateLayerUpload",            # start layer upload
      "ecr:UploadLayerPart",               # upload layer chunks
      "ecr:CompleteLayerUpload",           # finalise layer upload
      "ecr:PutImage",                      # push the final image manifest
      "ecr:BatchGetImage",                 # pull images (for cache)
      "ecr:GetDownloadUrlForLayer"         # pull layers (for cache)
    ]
    # Scoped to only ECR repos in this account that belong to this project
    resources = [
      "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project_name}/*"
    ]
  }

  # --- EKS: get cluster details to build kubeconfig ---
  statement {
    sid    = "EKSDescribeCluster"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"                # needed by aws eks update-kubeconfig
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${var.project_name}-cluster"
    ]
  }

  # --- STS: verify the workflow's own identity ---
  statement {
    sid    = "STSGetCallerIdentity"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

# -------------------------------------------------------------------
# IAM ROLE — the actual role GitHub Actions assumes
# -------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name      = "${var.project_name}-github-actions-role"
    ManagedBy = "terraform"
    Project   = var.project_name
  }
}

# -------------------------------------------------------------------
# IAM POLICY — attach the permissions to the role
# -------------------------------------------------------------------
resource "aws_iam_policy" "github_actions" {
  name        = "${var.project_name}-github-actions-policy"
  description = "Least-privilege permissions for GitHub Actions CI/CD pipeline"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json

  tags = {
    Name      = "${var.project_name}-github-actions-policy"
    ManagedBy = "terraform"
    Project   = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}