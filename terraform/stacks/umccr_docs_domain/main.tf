terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_docs_domain/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.21.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# CloudFront only accepts certificates issued in us-east-1.
provider "aws" {
  region = "us-east-1"
  alias  = "use1"
}

locals {
  stack_name_us = "umccr_docs_domain"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
    "Source"      = "https://github.com/umccr/infrastructure/blob/master/terraform/stacks/umccr_docs_domain"
  }

  # Empty outside the dev and prod workspaces, which the zone lookup below refuses.
  base_domain = lookup(var.base_domain, terraform.workspace, "")

  # The stage hostname, served by the docs CloudFront distribution in this account. It mirrors
  # `DOCS_DOMAIN_NAMES` in infrastructure/config.ts of umccr/docs-platform.
  docs_domain = "docs.${local.base_domain}"

  # An extra hostname served by the same distribution. Only prod has one: docs.umccr.org.
  docs_alias_domain = lookup(var.alias_domain, terraform.workspace, "")
}

# Hosted zone for this account's stage domain, e.g. dev.umccr.org
data "aws_route53_zone" "stage_zone" {
  name = "${local.base_domain}."

  lifecycle {
    precondition {
      condition     = local.base_domain != ""
      error_message = "docs.umccr.org runs in dev and prod only: select the dev or prod workspace, not ${terraform.workspace}."
    }
  }
}
