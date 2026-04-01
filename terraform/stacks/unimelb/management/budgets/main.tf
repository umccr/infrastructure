terraform {
  required_version = ">= 1.14.4"

  backend "s3" {
    bucket       = "terraform-states-363226301494-ap-southeast-2"
    key          = "management/budgets/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.31.0"
    }
  }
}


provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      "umccr:Stack"       = "uom_management"
      "umccr:Environment" = "management"
      "umccr:Creator"     = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  region          = data.aws_region.current.region
  this_account_id = data.aws_caller_identity.current.account_id

  # accounts with a configured budget; accounts with budget_usd = null are skipped
  member_accounts = {
    for k, v in var.member_accounts : k => v
    if v.budget_usd != null
  }

  member_account_ids = [for k, v in var.member_accounts : v.account_id]
}
