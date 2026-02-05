terraform {
  required_version = ">= 1.14.4"

  backend "s3" {
    bucket         = "terraform-states-363226301494-ap-southeast-2"
    key            = "management/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
    use_lockfile   = true
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
      "umccr:Stack"   = "uom_management"
      "umccr:Environment" : "management",
      "umccr:Creator" = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

locals {
  region                     = data.aws_region.current.region
  this_account_id            = data.aws_caller_identity.current.account_id
  data_account_id            = "503977275616"
  account_id_montauk         = "977251586657"
  cloudtrail_bucket_name_dev = "cloudtrail-logs-${local.this_account_id}-${local.region}"
}


# TODO: create CloudTrail bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_bucket_name_dev

  tags =     {
      "Name" = local.cloudtrail_bucket_name_dev
    }
}

# bucket policy to allow other UoM accounts trails to log to this bucket
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail.json
}

# From: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-set-bucket-policy-for-multiple-accounts.html
data "aws_iam_policy_document" "cloudtrail" {
  statement {
    sid = "CloudTrailAclCheck"
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
        "arn:aws:cloudtrail:${local.region}:${local.this_account_id}:trail/mgntTrail",
        "arn:aws:cloudtrail:${local.region}:${local.account_id_montauk}:trail/montaukTrail",
        "arn:aws:cloudtrail:${local.region}:${local.data_account_id}:trail/dataTrail"
      ]
    }
  }
  statement {
    sid = "CloudTrailWrite"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${local.this_account_id}/*",
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${local.account_id_montauk}/*",
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${local.data_account_id}/*"
    ]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${local.region}:${local.this_account_id}:trail/mgntTrail",
        "arn:aws:cloudtrail:${local.region}:${local.account_id_montauk}:trail/montaukTrail",
        "arn:aws:cloudtrail:${local.region}:${local.data_account_id}:trail/dataTrail"
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

