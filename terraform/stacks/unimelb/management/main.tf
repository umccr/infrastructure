terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    bucket         = "terraform-states-363226301494-ap-southeast-2"
    key            = "management/terraform.tfstate"
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

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  region                     = data.aws_region.current.name
  this_account_id            = data.aws_caller_identity.current.account_id
  data_account_id            = "503977275616"
  cloudtrail_bucket_name_dev = "cloudtrail-logs-${local.this_account_id}-${local.region}"
  common_tags = {
    "umccr:Environment" : "management",
    "umccr:Stack" : "uom_management"
  }
}


# TODO: create CloudTrail bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_bucket_name_dev

  tags = merge(
    local.common_tags,
    {
      "Name" = local.cloudtrail_bucket_name_dev
    }
  )
}

# bucket policy to allow other UoM accounts trails to log to this bucket
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail.json
}

# From: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-set-bucket-policy-for-multiple-accounts.html
data "aws_iam_policy_document" "cloudtrail" {
  statement {
    sid = "CloudTrail1"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
    ]
    resources = [
      aws_s3_bucket.cloudtrail.arn,
    ]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:region:${local.this_account_id}:trail/mgntTrail",
        "arn:aws:cloudtrail:region:${local.data_account_id}:trail/dataTrail"
      ]
    }
  }
  statement {
    sid = "CloudTrail2"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${local.this_account_id}/*",
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${local.data_account_id}/*"
    ]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:region:${local.this_account_id}:trail/mgntTrail",
        "arn:aws:cloudtrail:region:${local.data_account_id}:trail/dataTrail"
      ]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control"
      ]
    }
  }
}

