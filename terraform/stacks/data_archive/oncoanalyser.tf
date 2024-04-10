################################################################################
# Buckets

resource "aws_s3_bucket" "oncoanalyser_bucket" {
  bucket = var.oncoanalyser_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name" = var.oncoanalyser_bucket_name
    }
  )
}

##### Bucket Config
resource "aws_s3_bucket_public_access_block" "oncoanalyser_bucket" {
  bucket = aws_s3_bucket.oncoanalyser_bucket.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "oncoanalyser_bucket" {
  bucket = aws_s3_bucket.oncoanalyser_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "oncoanalyser_bucket" {
  bucket = aws_s3_bucket.oncoanalyser_bucket.id

  versioning_configuration {
    status = "Enabled" ## Should we disable versioning?
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "oncoanalyser_bucket" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.oncoanalyser_bucket]

  bucket = aws_s3_bucket.oncoanalyser_bucket.bucket

  rule {
    id = "base_rule"

    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    status = "Enabled"
  }

  rule {
    id = "analysis_data_rule"

    filter {
      prefix = "analysis_data/"
    }

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }

    status = "Enabled"
  }

  rule {
    id = "temp_rule"

    filter {
      prefix = "temp_data/"
    }

    # ONEZONE_IA requires min 30, so unless the expiration time
    # is increased, this is not needed
    # transition {
    #   days          = 30
    #   storage_class = "ONEZONE_IA"
    # }

    expiration {
      days = 30
    }

    status = "Enabled"
  }

}

resource "aws_s3_bucket_policy" "oncoanalyser_bucket" {
  bucket = aws_s3_bucket.oncoanalyser_bucket.id
  policy = data.aws_iam_policy_document.prod_cross_account_access.json
}

data "aws_iam_policy_document" "prod_cross_account_access" {
  statement {
    sid = "prod_cross_account_access"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::472057503814:root"]
    }

    actions = [
      "s3:List*",
      "s3:Get*",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:RestoreObject",
      "s3:PutObject"
    ]

    resources = [
      aws_s3_bucket.oncoanalyser_bucket.arn,
      "${aws_s3_bucket.oncoanalyser_bucket.arn}/*",
    ]
  }

  # TODO: test before implementation (possibility to look yourself out!)
  # statement {
  #   sid = "deny_sensitive_operations"

  #   effect = "Deny"

  #   actions = [
  #     "s3:DeleteBucketPolicy",
  #     "s3:PutBucketAcl",
  #     "s3:PutBucketPolicy",
  #     "s3:PutEncryptionConfiguration",
  #     "s3:PutObjectAcl"
  #   ]

  #   resources = [
  #     aws_s3_bucket.oncoanalyser_bucket.arn,
  #     "${aws_s3_bucket.oncoanalyser_bucket.arn}/*",
  #   ]

  #   condition {
  #     test     = "StringNotEquals"
  #     variable = "aws:SourceAccount"
  #     values   = ["503977275616"]
  #   }
  # }

}
