terraform {
  required_version = ">= 1.5.4"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_demo_admin/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "5.12.0"
      source  = "hashicorp/aws"
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
    "org.umccr:Environment" : "demo",
    "org.umccr:Stack" : "umccr_demo_admin"
  }

  elsa_data_tags = merge(local.common_tags, {
    "org.umccr:Product" : "ElsaData"
  })
}



resource "aws_iam_user" "elsa_data_object_signing" {
  name          = "elsa_data_object_signing"
  path          = "/elsa/"
  force_destroy = true
  tags          = local.elsa_data_tags
}

resource "aws_iam_group" "elsa_data_object_signing" {
  name = "elsa_data_object_signing_group"
  path = "/elsa/"
}

resource "aws_iam_group_membership" "elsa_data_object_signing" {
  name  = "${aws_iam_group.elsa_data_object_signing.name}_membership"
  group = aws_iam_group.elsa_data_object_signing.name
  users = [
    aws_iam_user.elsa_data_object_signing.name
  ]
}

resource "aws_iam_group_policy_attachment" "elsa_data_object_signing" {
  group      = aws_iam_group.elsa_data_object_signing.name
  policy_arn = aws_iam_policy.elsa_data_object_signing.arn
}

// allow Read access to the buckets and specific paths within the buckets

data "aws_iam_policy_document" "elsa_data_object_signing" {
  statement {
    actions = ["s3:GetBucketLocation"]
    resources = [
      for k, v in var.elsa_data_data_bucket_paths : format("arn:aws:s3:::%s", k)
    ]
  }

  statement {
    actions = ["s3:GetObject", "s3:GetObjectTagging"]
    resources = [
      for entry in flatten((
        [for bucket, bucket_paths in var.elsa_data_data_bucket_paths :
          [for path in bucket_paths : {
            bucket = bucket
            key    = path
      }]])) : format("arn:aws:s3:::%s/%s", entry.bucket, entry.key)
    ]
  }
}

resource "aws_iam_policy" "elsa_data_object_signing" {
  name_prefix = "elsa_data_object_signing"
  path        = "/elsa/"
  policy      = data.aws_iam_policy_document.elsa_data_object_signing.json
  tags        = local.elsa_data_tags
}
