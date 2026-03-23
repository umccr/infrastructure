terraform {
  required_version = ">= 1.14.4"

  backend "s3" {
    bucket       = "terraform-states-363226301494-ap-southeast-2"
    key          = "management/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.31.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}


provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      "umccr:Stack" = "uom_management"
      "umccr:Environment" : "management",
      "umccr:Creator" = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

locals {
  region          = data.aws_region.current.region
  this_account_id = data.aws_caller_identity.current.account_id

  # we should have a better way of managing this master list - possibly using AWS Organization OUs - as the
  # descendant accounts for an OU can be fetched via terraform. Would need coordinating with uni though
  data_account_id                = "503977275616"
  account_id_montauk             = "977251586657"
  account_id_grimmond            = "980504796380"
  account_id_breast_cancer_atlas = "550435500918"
  account_id_hofmann_main        = "465105354675"

  # all accounts that are not *this* management account
  account_id_list_without_management_account = [
    local.data_account_id,
    local.account_id_montauk,
    local.account_id_grimmond,
    local.account_id_breast_cancer_atlas,
    local.account_id_hofmann_main
  ]

  # a list of roles that will be performing terraform operations throughout our accounts
  # various secrets and buckets will be shared to all accounts, but only usable by those with these
  # roles

  # note that we have wildcard accounts here - so any use of these as conditions
  # *also* needs other conditions to restrict to just our accounts

  terraform_allowed_roles = [
    "arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_AWSAdministratorAccess_*",
    "arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_PlatformOwnerAccess_*"

  ]

  cloudtrail_bucket_name_dev = "cloudtrail-logs-${local.this_account_id}-${local.region}"
}


# TODO: create CloudTrail bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_bucket_name_dev

  tags = {
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

