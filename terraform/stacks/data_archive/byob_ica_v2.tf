################################################################################
# Variables

variable "analysis_data_bucket" {
  description = "This bucket is holding production data."
  default     = "org.umccr.data.analysis_data"
}
variable "analysis_data_prefix" {
  description = "The prefix under which all analysis data is collected."
  default     = "analysis_data/"
}

################################################################################
# Buckets

resource "aws_s3_bucket" "analysis_data_bucket" {
  bucket = var.analysis_data_bucket

  tags = merge(
    local.default_tags,
    {
      "Name"=var.analysis_data_bucket
    }
  )
}

##### Bucket Config
resource "aws_s3_bucket_public_access_block" "analysis_data_bucket" {
  bucket = aws_s3_bucket.analysis_data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analysis_data_bucket" {
  bucket = aws_s3_bucket.analysis_data_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "analysis_data_bucket" {
  bucket = aws_s3_bucket.analysis_data_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "analysis_data_bucket" {
  # Must have bucket versioning enabled first to apply noncurrent version expiration
  depends_on = [aws_s3_bucket_versioning.analysis_data_bucket]

  bucket = aws_s3_bucket.analysis_data_bucket.bucket

  rule {
    id = "base_rule"
    status = "Enabled"
    expiration {
      expired_object_delete_marker = true
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id = "analysis_data_rule"
    status = "Enabled"
    filter {
      prefix = var.analysis_data_prefix
    }
    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id = "temp_rule"
    status = "Enabled"
    filter {
      prefix = "temp_data/"
    }
  	expiration {
      days = 30
    }
    # ONEZONE_IA requires min 30, so unless the expiration time
    # is increased, this is not needed
    # transition {
    #   days          = 30
    #   storage_class = "ONEZONE_IA"
    # }
  }

}

resource "aws_s3_bucket_policy" "analysis_data_bucket" {
  bucket = aws_s3_bucket.analysis_data_bucket.id
  policy = data.aws_iam_policy_document.prod_cross_account_access.json
}

data "aws_iam_policy_document" "prod_ro_access" {
  statement {
	  sid = "prod_ro_access"
    principals {
      type        = "AWS"
      identifiers = ["472057503814"]
    }
    actions = [
      "s3:List*",
      "s3:Get*",
    ]
    resources = [
      aws_s3_bucket.analysis_data_bucket.arn,
      "${aws_s3_bucket.analysis_data_bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.analysis_data_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "DELETE", "PUT", "POST"]
    allowed_origins = ["https://ica.illumina.com"]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

################################################################################
# BYOB IAM User

resource "aws_iam_user" "icav2_byob_admin" {
  name = "icav2_byob_admin"
  path = "/icav2/"
  tags = local.default_tags
}

resource "aws_iam_group" "icav2" {
  name = "icav2"
  path = "/icav2/"
}

resource "aws_iam_group_membership" "icav2" {
  name  = "${aws_iam_group.icav2.name}_membership"
  group = aws_iam_group.icav2.name
  users = [
    aws_iam_user.icav2_byob_admin.name,
  ]
}

resource "aws_iam_group_policy_attachment" "icav2_group_policy_attachment" {
  group      = aws_iam_group.icav2.name
  policy_arn = aws_iam_policy.icav2_byob_user_policy.arn
}

data "aws_iam_policy_document" "icav2_byob_user_policy" {
  statement {
    actions = [
      "s3:PutBucketNotification",
      "s3:ListBucket",
      "s3:GetBucketNotification",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.analysis_data_bucket.id}"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:RestoreObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.analysis_data_bucket.id}/*"
    ]
  }

  statement {
    actions = [
      "sts:GetFederationToken",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "icav2_byob_user_policy" {
  name   = "icav2_byob_user_policy"
  path   = "/icav2/"
  policy = data.aws_iam_policy_document.icav2_byob_user_policy.json
}