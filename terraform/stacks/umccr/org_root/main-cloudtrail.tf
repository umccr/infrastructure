################################################################################
# Cloud Trails
# (note that these we existing resources created by hand/click-ops and then imported
#  into terraform many years later - so if they feel a bit wierd that is why)

resource "aws_cloudtrail" "org_trail" {
  name                       = "umccr-cloudtrail-org-root"
  is_multi_region_trail      = true
  is_organization_trail      = true
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.org_trail_log_group.arn}:*"
  cloud_watch_logs_role_arn  = "arn:aws:iam::650704067584:role/CloudTrail_CloudWatchLogs_Role_OrgTrail"
  enable_log_file_validation = true
  kms_key_id                 = aws_kms_key.org_trail_key.id
  s3_bucket_name             = aws_s3_bucket.cloudtrail_root.id
  sns_topic_name             = null
  event_selector {
    exclude_management_event_sources = []
    include_management_events        = true
    read_write_type                  = "All"
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }
  insight_selector {
    insight_type = "ApiCallRateInsight"
  }
}

resource "aws_cloudwatch_log_group" "org_trail_log_group" {
  name              = "CloudTrail/DefaultLogGroup"
  log_group_class   = "STANDARD"
  retention_in_days = 0
}

# __generated__ by Terraform from "arn:aws:kms:ap-southeast-2:650704067584:key/c7169941-5700-4b98-b128-2dc1d2dd2607"
resource "aws_kms_key" "org_trail_key" {
  bypass_policy_lockout_safety_check = null
  custom_key_store_id                = null
  customer_master_key_spec           = "SYMMETRIC_DEFAULT"
  deletion_window_in_days            = null
  description                        = "The key created by CloudTrail to encrypt log files. Created Wed Aug 26 01:33:00 UTC 2020"
  enable_key_rotation                = true
  is_enabled                         = true
  key_usage                          = "ENCRYPT_DECRYPT"
  multi_region                       = false
  policy = jsonencode({
    Id = "Key policy created by CloudTrail"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
      {
        Action = "kms:GenerateDataKey*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Resource = "*"
        Sid      = "Allow CloudTrail to encrypt logs"
      },
      {
        Action = "kms:DescribeKey"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Resource = "*"
        Sid      = "Allow CloudTrail to describe key"
      },
      {
        Action = ["kms:Decrypt", "kms:ReEncryptFrom"]
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = "650704067584"
          }
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Resource = "*"
        Sid      = "Allow principals in the account to decrypt log files"
      },
      {
        Action = "kms:CreateAlias"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = "650704067584"
            "kms:ViaService"    = "ec2.ap-southeast-2.amazonaws.com"
          }
        }
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Resource = "*"
        Sid      = "Allow alias creation during setup"
      }, {
        Action = ["kms:Decrypt", "kms:ReEncryptFrom"]
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = "650704067584"
          }
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:650704067584:trail/*"
          }
        }
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Resource = "*"
        Sid      = "Enable cross account log decryption"
      }]
    Version = "2012-10-17"
  })
  rotation_period_in_days = 365
  xks_key_id              = null
}

