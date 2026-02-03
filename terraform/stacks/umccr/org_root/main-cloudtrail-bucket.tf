################################################################################
# Cloud Trail Bucket
#
# Setting for the bucket that stores all our organisation cloudtrails

# by default we want to keep cloudtrail logs for 7 years - but if listed here then this is
# an override of their expiry (for dev accounts etc)
variable "override_cloudtrail_expiration_days" {
  type = map(number)
  default = {
    "843407916570" = 365 # dev
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
          "Sid" : "AWSCloudTrailAclCheck20150319",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudtrail.amazonaws.com"
          },
          "Action" : ["s3:GetBucketAcl", "s3:ListBucket"],
          "Resource" : "arn:aws:s3:::umccr-cloudtrail-org-root",
          #"Condition" : {
          #  "StringEquals" : {
          #    "aws:SourceArn" : "arn:aws:cloudtrail:*:${data.aws_organizations_organization.current.master_account_id}:trail/*"
          #  }
          #}
        },
        #{
        #  "Sid" : "AllowCloudTrailWritesThisAccount",
        #  "Effect" : "Allow",
        #  "Principal" : {
        #    "Service" : "cloudtrail.amazonaws.com"
        #  },
        #  "Action" : "s3:PutObject",
        #  "Resource" : "arn:aws:s3:::umccr-cloudtrail-org-root/AWSLogs/650704067584/*"
        #},
        {
          "Sid" : "AWSCloudTrailWrite20150319",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudtrail.amazonaws.com"
          },
          "Action" : "s3:PutObject",
          "Resource" : "arn:aws:s3:::umccr-cloudtrail-org-root/AWSLogs/o-p5xvdd9ddb/*",
          "Condition": {
            "StringEquals": {
              "s3:x-amz-acl": "bucket-owner-full-control"
            }
          }
        }
      ]
  })
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
