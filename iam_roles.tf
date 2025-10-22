# ---------------------------------------------------------------------------
# IRSA Role for RDS Snapshot Manager Pod
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role_with_oidc" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:default:rds-snapshot-manager"]
    }
  }
}

resource "aws_iam_role" "rds_snapshot_role" {
  name               = "${var.cluster_name}-rds-snapshot-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_with_oidc.json
}

resource "aws_iam_role_policy" "rds_snapshot_policy" {
  name = "${var.cluster_name}-rds-snapshot-policy"
  role = aws_iam_role.rds_snapshot_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "rds:CopyDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC Role for Secure ECR Push
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Extraordinarytechy/idp-flagship-app:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_role" {
  name               = "${var.cluster_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

resource "aws_iam_role_policy" "ecr_push_policy" {
  name = "${var.cluster_name}-ecr-push-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}
