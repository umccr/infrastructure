terraform {
  backend "s3" {
    bucket         = "umccr-terraform-states-org"
    key            = "org_root/terraform.tfstate"
    region         = "ap-southeast-2"
    use_lockfile   = true
  }
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Stack = var.stack_name
    }
  }
}

################################################################################
# Get Organisation information (output them just to show what info we have)

# Use the data source to retrieve the organization details
data "aws_organizations_organization" "current" {}

data "aws_organizations_organizational_unit" "production_ou" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
  name      = "production"
}

data "aws_organizations_organizational_unit_descendant_accounts" "production_accounts" {
  parent_id = data.aws_organizations_organizational_unit.production_ou.id
}

data "aws_organizations_organizational_unit" "operational_ou" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
  name      = "operational"
}

data "aws_organizations_organizational_unit_descendant_accounts" "operational_accounts" {
  parent_id = data.aws_organizations_organizational_unit.operational_ou.id
}

output "all_account_ids" {
  description = "List of all organization account IDs"
  value       = data.aws_organizations_organization.current.accounts[*].id
}

output "production_account_ids" {
  description = "List of all production account IDs (according to OU)"
  value       = data.aws_organizations_organizational_unit_descendant_accounts.production_accounts.accounts[*].id
}

output "operational_account_ids" {
  description = "List of all operational account IDs (according to OU)"
  value       = data.aws_organizations_organizational_unit_descendant_accounts.operational_accounts.accounts[*].id
}

output "all_accounts_details" {
  description = "List of all accounts with details"
  value       = data.aws_organizations_organization.current.accounts
}

################################################################################
# Buckets

resource "aws_s3_bucket" "cloudtrail_root" {
  bucket = var.cloudtrail_bucket
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail_root" {
  bucket = aws_s3_bucket.cloudtrail_root.id

  # disable ACLs entirely on the bucket
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# THE CURRENT DEPLOYED CLOUDTRAIL BUCKET HAS A BUNCH OF LIFECYCLE RULES
# BUT THEY ARE ALL DISABLED. LEAVING THIS HERE AS THE NEW CONSTRUCT
# IF WE WANTED TO SWITCH THEM ON
#
# resource "aws_s3_bucket_lifecycle_configuration" "example" {
#   for_each = toset(data.aws_organizations_organization.current.accounts[*].id)
#
#   bucket = aws_s3_bucket.cloudtrail_root.id
#
#   rule {
#     id     = "${each.value} logs lifecycle"
#     status = "Enabled"
#
#     filter {
#       prefix = "AWSLogs/o-p5xvdd9ddb/${each.value}"
#     }
#
#     transition {
#       days          = 90
#       storage_class = "DEEP_ARCHIVE"
#     }
#
#     expiration {
#       days          = lookup(var.override_cloudtrail_expiration_days, each.value, 7*365)
#     }
#   }
# }

# by default we want to keep cloudtrail logs for 7 years - but if listed here then this is
# an override of their expiry (for dev accounts etc)
variable "override_cloudtrail_expiration_days" {
  type = map(number)
  default = {
    "843407916570" = 365
  }
}


resource "aws_s3_bucket_policy" "cloudtrail_root" {
  bucket = aws_s3_bucket.cloudtrail_root.id

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
            "Action": ["s3:GetBucketAcl", "s3:ListBucket"],
            "Resource": "arn:aws:s3:::umccr-cloudtrail-org-root"
        },
        {
            "Sid": "AllowCloudTrailWritesThisAccount",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::umccr-cloudtrail-org-root/AWSLogs/650704067584/*"
        },
        {
            "Sid": "AllowCloudTrailWritesOrganisation",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::umccr-cloudtrail-org-root/AWSLogs/o-p5xvdd9ddb/*"
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
}
