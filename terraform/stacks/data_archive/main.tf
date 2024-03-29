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
provider "awscc" {
  region = local.region
}


data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  region = "ap-southeast-2"
  stack_name = "data_archive"

  default_tags = {
    "Stack"       = local.stack_name
    "Creator"     = "terraform"
    "Environment" = "data_archive"
  }

}


# resource "aws_s3_account_public_access_block" "account_pab" {
#   block_public_acls   = true
#   block_public_policy = true
# }

