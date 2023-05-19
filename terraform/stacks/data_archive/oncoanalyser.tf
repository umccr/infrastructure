################################################################################
# Buckets

resource "aws_s3_bucket" "oncoanalyser_bucket" {
  bucket = var.oncoanalyser_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name"=var.oncoanalyser_bucket_name
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
    status = "Enabled"  ## Should we disable versioning?
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "oncoanalyser_bucket" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.oncoanalyser_bucket]

  bucket = aws_s3_bucket.oncoanalyser_bucket.bucket

  rule {
    id = "oncoanalyser_bucket_lifecycle_config"

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }

    # Versioning configuration
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
}