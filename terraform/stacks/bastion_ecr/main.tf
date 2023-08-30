terraform {
  required_version = ">= 1.4.2"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "bastion_ecr/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "4.59.0"
      source  = "hashicorp/aws"
    }
  }
}

locals {
  # Stack name in underscore
  stack_name_us = "bastion_ecr"

  # Stack name in dash
  stack_name_dash = "bastion-ecr"
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Stack       = local.stack_name_us
      Creator     = "terraform"
      Environment = "bastion"
    }
  }
}

####
# cttso-ica-to-pieriandx
#

resource "aws_ecr_repository" "cttso_ica_to_pieriandx" {
  name                 = "cttso-ica-to-pieriandx"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository_policy" "cttso_ica_to_pieriandx_cross_accounts" {
  repository = aws_ecr_repository.cttso_ica_to_pieriandx.name
  policy     = templatefile("policies/cross_accounts_policy_umccr.json", {})
}

# Policy on untagged image
resource "aws_ecr_lifecycle_policy" "cttso_ica_to_pieriandx_lifecycle" {
  repository = aws_ecr_repository.cttso_ica_to_pieriandx.name
  policy     = templatefile("policies/untagged_image_policy.json", {})
}


####
# oncoanalyser
#

resource "aws_ecr_repository" "oncoanalyser" {
  name                 = "oncoanalyser"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository_policy" "oncoanalyser_cross_accounts" {
  repository = aws_ecr_repository.oncoanalyser.name
  policy     = templatefile("policies/cross_accounts_policy_umccr.json", {})
}

# Policy on untagged image
resource "aws_ecr_lifecycle_policy" "oncoanalyser_lifecycle" {
  repository = aws_ecr_repository.oncoanalyser.name
  policy     = templatefile("policies/untagged_image_policy.json", {})
}


####
# star-nf
#

resource "aws_ecr_repository" "star_align_nf" {
  name                 = "star-align-nf"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository_policy" "star_align_nf_cross_accounts" {
  repository = aws_ecr_repository.star_align_nf.name
  policy     = templatefile("policies/cross_accounts_policy_umccr.json", {})
}

# Policy on untagged image
resource "aws_ecr_lifecycle_policy" "star_align_nf_lifecycle" {
  repository = aws_ecr_repository.star_align_nf.name
  policy     = templatefile("policies/untagged_image_policy.json", {})
}


####
# sash
#

resource "aws_ecr_repository" "sash" {
  name                 = "sash"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository_policy" "sash_cross_accounts" {
  repository = aws_ecr_repository.sash.name
  policy     = templatefile("policies/cross_accounts_policy_umccr.json", {})
}

# Policy on untagged image
resource "aws_ecr_lifecycle_policy" "sash_lifecycle" {
  repository = aws_ecr_repository.sash.name
  policy     = templatefile("policies/untagged_image_policy.json", {})
}
