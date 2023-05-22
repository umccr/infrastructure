################################################################################
# Buckets

resource "aws_s3_bucket" "raw_data_bucket" {
  bucket = var.raw_data_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name"=var.raw_data_bucket_name
    }
  )
}

################################################################################
# Bucket configs

resource "aws_s3_bucket_public_access_block" "raw_data_bucket" {
  bucket = aws_s3_bucket.raw_data_bucket.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data_bucket" {
  bucket = aws_s3_bucket.raw_data_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "raw_data_bucket" {
  bucket = aws_s3_bucket.raw_data_bucket.id

  versioning_configuration {
    status = "Enabled"  ## Should we disable versioning?
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw_data_bucket" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.raw_data_bucket]

  bucket = aws_s3_bucket.raw_data_bucket.bucket

  rule {
    id = "raw_data_bucket_lifecycle_config"

    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }

    # Versioning configuration
    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    status = "Enabled"
  }
}