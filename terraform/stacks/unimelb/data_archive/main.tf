terraform {
  required_version = ">= 1.3.3"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "data_archive/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

################################################################################
# Generic resources

# Configure the AWS Provider
provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  region          = "ap-southeast-2"
  stack_name      = "data_archive"
  this_account_id = data.aws_caller_identity.current.account_id
  mgmt_account_id = "363226301494"
  account_id_prod = "472057503814"
  account_id_stg  = "455634345446"
  account_id_dev  = "843407916570"
  account_id_org  = "650704067584"

  default_tags = {
    "Stack"       = local.stack_name
    "Creator"     = "terraform"
    "Environment" = "data_archive"
  }
}

################################################################################
# Common resources

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


