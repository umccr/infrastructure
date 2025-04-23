terraform {
  required_version = ">= 1.3.3"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "terraform-state-977251586657-ap-southeast-2"
    key            = "terraform-state/terraform.tfstate"
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
  stack_name      = "montauk"
  account_id_self = data.aws_caller_identity.current.account_id
  account_id_mgmt = "363226301494"
  account_id_prod = "472057503814"
  account_id_org  = "650704067584"

  default_tags = {
    "umccr:Stack"       = local.stack_name
    "umccr:Creator"     = "terraform"
    "umccr:Environment" = "ResearchProject"
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


