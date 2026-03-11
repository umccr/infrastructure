################################################################################
# Cloud Trail Bucket
#
# Setting for the bucket that stores all our organisation cloudtrails

# by default we want to keep cloudtrail logs for a long time - but if listed here then this is
# an override of their expiry (for dev accounts etc)
variable "override_cloudtrail_expiration_days" {
  type = map(number)
  default = {
    # dev
    "843407916570" = 365
    # onboarding
    "702956374523" = 365
    # guardians dev
    "842385035780" = 365
  }
}

# the bucket where we can store all the organisation cloudtrail logs
resource "aws_s3_bucket" "cloudtrail_root" {
  bucket = var.cloudtrail_bucket
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail_root" {
  bucket = aws_s3_bucket.cloudtrail_root.id

  # disable ACLs entirely on the bucket as is the modern recommendation
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_root" {
  bucket = aws_s3_bucket.cloudtrail_root.id

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AWSCloudTrailAclCheck",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudtrail.amazonaws.com"
          },
          "Action" : ["s3:GetBucketAcl", "s3:ListBucket"],
          "Resource" : aws_s3_bucket.cloudtrail_root.arn
          "Condition" : {
            "StringEquals" : {
              "aws:SourceArn" : aws_cloudtrail.org_trail.arn
            }
          }
        },
        {
          "Sid" : "AWSCloudTrailWrite",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudtrail.amazonaws.com"
          },
          "Action" : "s3:PutObject",
          "Resource" : "${aws_s3_bucket.cloudtrail_root.arn}/AWSLogs/${data.aws_organizations_organization.current.id}/*",
          "Condition" : {
            "StringEquals" : {
              "aws:SourceArn" : aws_cloudtrail.org_trail.arn
            }
          }
        }
      ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_root" {
  bucket = aws_s3_bucket.cloudtrail_root.id

  # a lifecycle rule per account
  dynamic "rule" {
    for_each = toset(local.all_account_ids)

    content {
      id     = "Account ${rule.value} logs lifecycle - tier 60 days, expire ${lookup(var.override_cloudtrail_expiration_days, rule.value, 7 * 365)} days"
      status = "Enabled"

      filter {
        prefix = "AWSLogs/${data.aws_organizations_organization.current.id}/${rule.value}/"
      }

      transition {
        days          = 60
        storage_class = "INTELLIGENT_TIERING"
      }

      expiration {
        days = lookup(var.override_cloudtrail_expiration_days, rule.value, 7 * 365)
      }
    }
  }
}
