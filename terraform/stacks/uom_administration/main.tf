terraform {
  required_version = ">= 1.0.5"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "uom_administration/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.56.0"
    }
  }
}


provider "aws" {
  region = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = {
    "Environment": "org",
    "Stack": var.stack_name
  }
}


################################################################################
## Users

# User account for Jennifer (jennifer.graham@unimelb.edu.au)
resource "aws_iam_user" "jennifer" {
  name = "jennifer"
  path = "/uom/"
  force_destroy = true
  tags = {
    email   = "jennifer.graham@unimelb.edu.au",
    name    = "Jen Graham-Williams",
    keybase = ""
  }
}

################################################################################
# Groups

# uom_billing_reader
resource "aws_iam_group" "uom_billing_reader" {
  name = "uom_billing_reader"
  path = "/uom/"
}

## Group permissions

# default user policy to allow self management of user credentials
resource "aws_iam_group_policy_attachment" "default_user_policy_attachment" {
  group      = aws_iam_group.uom_billing_reader.name
  policy_arn = aws_iam_policy.default_user_policy.arn
}

# read only access to billing
resource "aws_iam_group_policy_attachment" "aws_billing_read_only_access_policy_attachment" {
  group      = aws_iam_group.uom_billing_reader.name
  policy_arn = var.aws_billing_read_only_access_policy_arn
}

# full access to AWS support centre
resource "aws_iam_group_policy_attachment" "aws_support_access_policy_attachment" {
  group      = aws_iam_group.uom_billing_reader.name
  policy_arn = var.aws_support_access_policy_arn
}

####################
# Group memberships

# Default
resource "aws_iam_group_membership" "uom_billing_reader" {
  name  = "${aws_iam_group.uom_billing_reader.name}_membership"
  group = aws_iam_group.uom_billing_reader.name
  users = [
    aws_iam_user.jennifer.name
  ]
}

####################
# Custom IAM policies

resource "aws_iam_policy" "default_user_policy" {
  name_prefix = "default_user_policy"
  path        = "/uom/"
  policy = file("policies/default-user-policy.json")
}
