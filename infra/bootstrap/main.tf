# One-time, account-level resources shared by every environment:
#   - S3 bucket for Terraform remote state (native S3 locking, no DynamoDB)
#   - ECR repository (one image is built once and promoted staging -> production)
#   - GitHub OIDC provider and least-privilege IAM roles for GitHub Actions
#     (no long-lived AWS keys stored in GitHub)

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------
# Terraform state bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project}-tfstate-${local.account_id}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Container registry
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = var.project
  image_tag_mutability = "IMMUTABLE" # a git SHA always points to the same image
  force_delete         = var.allow_destroy

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last ${var.images_to_keep} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.images_to_keep
      }
      action = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Role used by the build job on the main branch: push images to ECR only.
data "aws_iam_policy_document" "ecr_push_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name               = "${var.project}-gha-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.ecr_push_trust.json
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid     = "PushImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

# One deploy role per GitHub environment. Each role can only be assumed by a
# job running in that GitHub environment, so production deploys go through
# the environment's protection rules (required reviewers).
data "aws_iam_policy_document" "deploy_trust" {
  for_each = toset(var.environments)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${each.key}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each = toset(var.environments)

  name               = "${var.project}-gha-deploy-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust[each.key].json
}

data "aws_iam_policy_document" "deploy" {
  for_each = toset(var.environments)

  statement {
    sid     = "TaskDefinitions"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"] # these ECS actions do not support resource-level permissions
  }

  statement {
    sid     = "UpdateService"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [
      "arn:aws:ecs:${var.region}:${local.account_id}:service/${var.project}-${each.key}/${var.project}-${each.key}",
    ]
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-${each.key}-task",
      "arn:aws:iam::${local.account_id}:role/${var.project}-${each.key}-exec",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "VerifyImageExists"
    actions   = ["ecr:DescribeImages"]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  for_each = toset(var.environments)

  name   = "ecs-deploy"
  role   = aws_iam_role.deploy[each.key].id
  policy = data.aws_iam_policy_document.deploy[each.key].json
}
