/**
 * An ECR repository for storing the Lambda function code. Operates
 * as a pull through of a Docker image from GHCR.
 */

data "aws_caller_identity" "current" {}
data "aws_ecr_authorization_token" "this" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  ecr_registry  = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  ecr_repo_url  = "${local.ecr_registry}/${var.name}"
  image_tag     = var.ghcr_tag
  ecr_image_uri = "${local.ecr_repo_url}:${local.image_tag}"
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  // this is just a cache of our published GHCR so it can be
  // cleared aggressively
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 2 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 2
      }
      action = { type = "expire" }
    }]
  })
}

resource "docker_image" "source" {
  name         = "${var.ghcr_repo}:${var.ghcr_tag}"
  keep_locally = false
  platform     = "linux/arm64"
}

resource "docker_tag" "ecr" {
  source_image = docker_image.source.image_id
  target_image = local.ecr_image_uri
}

resource "docker_registry_image" "ecr" {
  name          = docker_tag.ecr.target_image
  keep_remotely = true

  depends_on = [
    aws_ecr_repository.this,
    docker_tag.ecr,
  ]
}
