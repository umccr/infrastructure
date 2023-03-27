terraform {
  required_version = ">= 1.4.2"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_datalake/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.59.0"
    }
  }
}

locals {
  # Stack name in underscore
  stack_name_us = "umccr_datalake"

  # Stack name in dash
  stack_name_dash = "umccr-datalake"

  datalake_version = "v1"
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Stack       = local.stack_name_us
      Creator     = "terraform"
      Environment = terraform.workspace
    }
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}

data "aws_iam_policy" "managed_glue_service_role" {
  name = "AWSGlueServiceRole"
}

data "aws_s3_bucket" "datalake" {
  bucket = "${local.stack_name_dash}-${terraform.workspace}"
}

resource "aws_iam_role" "datalake_role" {
  name               = "AWSGlueServiceRole-${local.stack_name_dash}"
  assume_role_policy = templatefile("policies/datalake_assume_role_policy.json", {})
}

resource "aws_iam_role_policy" "datalake_role_inline_policy" {
  name = "AWSGlueServiceRole-${local.stack_name_dash}"
  role = aws_iam_role.datalake_role.id

  policy = templatefile("policies/datalake_role_inline_policy.json", {
    bucket      = data.aws_s3_bucket.datalake.bucket
    account_id  = data.aws_caller_identity.current.account_id
    sse_key_arn = data.aws_kms_alias.s3.arn
  })

  # See
  # https://docs.aws.amazon.com/glue/latest/dg/crawler-prereqs.html
  # https://docs.aws.amazon.com/glue/latest/dg/create-an-iam-role.html
}

resource "aws_iam_role_policy_attachment" "datalake_role_managed_policy" {
  role       = aws_iam_role.datalake_role.name
  policy_arn = data.aws_iam_policy.managed_glue_service_role.arn
}
