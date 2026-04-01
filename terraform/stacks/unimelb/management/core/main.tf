terraform {
  required_version = ">= 1.14.4"

  backend "s3" {
    bucket       = "terraform-states-363226301494-ap-southeast-2"
    key          = "management/core/terraform.tfstate"
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

data "aws_partition" "current" {}

locals {
  region          = data.aws_region.current.region
  this_account_id = data.aws_caller_identity.current.account_id

  # all accounts that are not *this* management account
  # we should have a better way of managing this master list - possibly using AWS Organization OUs - as the
  # descendant accounts for an OU can be fetched via terraform. Would need coordinating with uni though
  account_id_list_without_management_account = [
    for k, v in var.member_accounts : v.account_id
    if v.account_id != local.this_account_id
  ]

  # a list of roles that will be performing terraform operations throughout our accounts
  # various secrets and buckets will be shared to all accounts, but only usable by those with these
  # roles

  # note that we have wildcard accounts here - so any use of these as conditions
  # *also* needs other conditions to restrict to just our accounts

  terraform_allowed_roles = [
    "arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_AWSAdministratorAccess_*",
    "arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_PlatformOwnerAccess_*",
  ]

  cloudtrail_bucket_name = "cloudtrail-logs-${local.this_account_id}-${local.region}"
}
