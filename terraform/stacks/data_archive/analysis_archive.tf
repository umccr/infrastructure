################################################################################
# Local constants

locals {
  # The bucket holding all archived analysis data
  analysis_archive_bucket_name = "archive-prod-analysis-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

################################################################################
# Buckets

resource "aws_s3_bucket" "analysis_archive" {
  bucket = local.analysis_archive_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name"=local.analysis_archive_bucket_name,
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analysis_archive" {
  bucket = aws_s3_bucket.analysis_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "analysis_archive" {

  bucket = aws_s3_bucket.analysis_archive.id

  rule {
    id = "base_rule"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id = "deep_archive_greater_1mb"
    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }
    filter {
      object_size_greater_than = 1000000
    }
    status = "Enabled"
  }

  rule {
    id = "archive_instant_less_1mb"
    transition {
      days          = 0
      storage_class = "GLACIER_IR"
    }
    filter {
      object_size_less_than = 1000000
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "analysis_archive" {
  bucket = aws_s3_bucket.analysis_archive.id
  policy = data.aws_iam_policy_document.analysis_archive.json
}

data "aws_iam_policy_document" "analysis_archive" {
  # Statement to allow uploads from a dedicated role in the dev account
  statement {
	  sid = "AllowUploadFromDevInstanceRole"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::843407916570:role/EC2-to-S3"]
    }
    actions = [
      "s3:List*",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.analysis_archive.arn,
      "${aws_s3_bucket.analysis_archive.arn}/*",
    ]
  }
  # # Statement to allow access to any principal from the dev account
  # statement {
	#   sid = "prod_list_access"
  #   principals {
  #     type        = "AWS"
  #     identifiers = ["472057503814"]
  #   }
  #   actions = [
  #     "s3:List*"
  #   ]
  #   resources = [
  #     aws_s3_bucket.analysis_archive.arn,
  #   ]
  # }
}
