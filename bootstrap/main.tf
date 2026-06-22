locals {
  services = [
    "api-gateway",
    "order-service",
    "inventory-service",
    "payment-service",
    "notification-service",
    "shipping-service",
    "worker",
    "scheduler",
    "dashboard-api"
  ]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.services)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-bucket-muna"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:munaai/ecs-microservices-platform:*"
      ]
    }
  }
}

resource "aws_iam_role" "ecs_microservices_github_actions" {
  name               = "github-actions-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ecs_microservices_github_actions_admin" {
  role       = aws_iam_role.ecs_microservices_github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}