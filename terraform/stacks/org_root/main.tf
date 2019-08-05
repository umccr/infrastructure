terraform {
  required_version = "~> 0.11.14"

  backend "s3" {
    bucket         = "umccr-terraform-states-org"
    key            = "org_root/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  common_tags = "${map(
    "Stack", "${var.stack_name}"
  )}"
}

################################################################################
# Buckets

resource "aws_s3_bucket" "cloudtrail_root" {
  bucket = "${var.cloudtrail_bucket}"

  lifecycle_rule {
    id      = "org_account"                       # org account
    prefix  = "AWSLogs/o-p5xvdd9ddb/650704067584"
    enabled = false

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }

  lifecycle_rule {
    id      = "bastion_account"                   # bastion account
    prefix  = "AWSLogs/o-p5xvdd9ddb/383856791668"
    enabled = false

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }

  lifecycle_rule {
    id      = "prod_account"                      # prod account
    prefix  = "AWSLogs/o-p5xvdd9ddb/472057503814"
    enabled = false

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }

  lifecycle_rule {
    id      = "agha_account"                      # agha account
    prefix  = "AWSLogs/o-p5xvdd9ddb/602836945884"
    enabled = false

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }

  lifecycle_rule {
    id      = "arvados_agha_account"              # ArvadosAGHA account
    prefix  = "AWSLogs/o-p5xvdd9ddb/941767615664"
    enabled = false

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }

  lifecycle_rule {
    id      = "dev_account"                       # dev account
    prefix  = "AWSLogs/o-p5xvdd9ddb/843407916570"
    enabled = false

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365 # keep for one year
    }
  }

  lifecycle_rule {
    id      = "old_dev_account"                   # old dev account
    prefix  = "AWSLogs/o-p5xvdd9ddb/620123204273"
    enabled = false

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365 # keep for one year
    }
  }

  lifecycle_rule {
    id      = "onboarding_account"                # onboarding account
    prefix  = "AWSLogs/o-p5xvdd9ddb/702956374523"
    enabled = true

    transition {
      days          = 30
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365 # keep for one year
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_root" {
  bucket = "${aws_s3_bucket.cloudtrail_root.id}"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck20150319",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::umccr-cloudtrail-org-root"
        },
        {
            "Sid": "AWSCloudTrailWrite20150319",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::umccr-cloudtrail-org-root/AWSLogs/650704067584/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        },
        {
            "Sid": "AWSCloudTrailWrite20150319",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::umccr-cloudtrail-org-root/AWSLogs/o-p5xvdd9ddb/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

################################################################################
# SNS

resource "aws_sns_topic" "chatbot_slack_topic" {
  name_prefix  = "chatbot_slack_topic"
  display_name = "chatbot_slack_topic"

  tags = "${local.common_tags}"
}
