terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    bucket         = "terraform-states-339712978718-ap-southeast-1"
    key            = "longread/terraform.tfstate"
    region         = "ap-southeast-1"
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
  region  = "ap-southeast-1"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  region          = "ap-southeast-1"
  stack_name      = "longread"
  this_account_id = data.aws_caller_identity.current.account_id

  default_tags = {
    "Stack"       = local.stack_name
    "Creator"     = "terraform"
    "Environment" = "longread"
  }
}
