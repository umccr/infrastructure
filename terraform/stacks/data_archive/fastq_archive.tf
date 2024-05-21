################################################################################
# Local constants

locals {
  # The bucket holding all archived FASTQ data
  # fastq_archive_bucket_name = "${data.aws_caller_identity.current.account_id}-fastq-archive"
  fastq_archive_bucket_name = "archive-prod-fastq-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

################################################################################
# Buckets

resource "aws_s3_bucket" "fastq_archive" {
  bucket = local.fastq_archive_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name"=local.fastq_archive_bucket_name,
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fastq_archive" {
  bucket = aws_s3_bucket.fastq_archive.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "fastq_archive" {

  bucket = aws_s3_bucket.fastq_archive.bucket

  rule {
    id = "base_rule"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id = "deep_archive_greater_5mb"
    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }
    filter {
      object_size_greater_than = 5000000
    }
    status = "Enabled"
  }

  rule {
    id = "archive_instant_less_5mb"
    transition {
      days          = 0
      storage_class = "GLACIER_IR"
    }
    filter {
      object_size_less_than = 5000000
    }
    status = "Enabled"
  }
}

# resource "aws_s3_bucket_policy" "fastq_archive" {
#   bucket = aws_s3_bucket.fastq_archive.id
#   policy = data.aws_iam_policy_document.fastq_archive.json
# }

# data "aws_iam_policy_document" "fastq_archive" {
#   statement {
# 	  sid = "prod_list_access"
#     principals {
#       type        = "AWS"
#       identifiers = ["472057503814"]
#     }
#     actions = [
#       "s3:List*",
#       "s3:GetBucketLocation",
#     ]
#     resources = [
#       aws_s3_bucket.fastq_archive.arn,
#       "${aws_s3_bucket.fastq_archive.arn}/*",
#     ]
#   }
# }
