################################################################################
# Local constants

locals {
  # The bucket holding all "active" production data
  pipeline_data_bucket_name = "${data.aws_caller_identity.current.account_id}-pipeline-cache"
  # prefix for the BYOB data in ICAv2
  icav2_prefix = "byob-icav2/"
  # prefix for the "production" project in ICAv2
  icav2_prod_project_prefix = "${local.icav2_prefix}production/"
  # prefix for the "staging" project in ICAv2
  icav2_stg_project_prefix = "${local.icav2_prefix}staging/"
  # prefix for the "validation-data" project in ICAv2
  icav2_val_project_prefix = "${local.icav2_prefix}validation-data/"
  # prefix for oncoanalyser pipelines
  oa_prod_prefix = "oncoanalyser/production/"
}

################################################################################
# Buckets

resource "aws_s3_bucket" "pipeline_data" {
  bucket = local.pipeline_data_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name"=local.pipeline_data_bucket_name
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_data" {
  bucket = aws_s3_bucket.pipeline_data.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "pipeline_data" {
  bucket = aws_s3_bucket.pipeline_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "pipeline_data" {
  # Must have bucket versioning enabled first to apply noncurrent version expiration
  depends_on = [aws_s3_bucket_versioning.pipeline_data]

  bucket = aws_s3_bucket.pipeline_data.bucket

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
    id = "icav2_data_it_rule"
    status = "Enabled"
    filter {
      prefix = "${local.icav2_prefix}"
    }
    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_policy" "pipeline_data" {
  bucket = aws_s3_bucket.pipeline_data.id
  policy = data.aws_iam_policy_document.pipeline_data.json
}

data "aws_iam_policy_document" "pipeline_data" {
  statement {
	  sid = "prod_lo_access"
    principals {
      type        = "AWS"
      identifiers = ["472057503814"]
    }
    actions = [
      "s3:List*",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.pipeline_data.arn,
      "${aws_s3_bucket.pipeline_data.arn}/*",
    ]
  }
  statement {
	  sid = "icav2_cross_account_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::079623148045:role/ica_aps2_crossacct"]
    }
    actions = [
      "s3:PutObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.pipeline_data.arn,
      "${aws_s3_bucket.pipeline_data.arn}/*",
    ]
  }
}


# CORS configuration for ILMN BYO buckets to support UI uploads
# ref: https://help.ica.illumina.com/home/h-storage/s-awss3
resource "aws_s3_bucket_cors_configuration" "pipeline_data" {
  bucket = aws_s3_bucket.pipeline_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["https://ica.illumina.com"]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

################################################################################
# BYOB IAM User for ICAv2
# ref: https://help.ica.illumina.com/home/h-storage/s-awss3
# NOTE: manipulating IAM user/groups in UoM accounts requires Owner access

resource "aws_iam_user" "icav2_pipeline_data_admin" {
  name = "icav2_pipeline_data_admin"
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
    aws_iam_user.icav2_pipeline_data_admin.name,
  ]
}

resource "aws_iam_group_policy_attachment" "icav2_group_policy_attachment" {
  group      = aws_iam_group.icav2.name
  policy_arn = aws_iam_policy.icav2_pipeline_data_user_policy.arn
}

data "aws_iam_policy_document" "icav2_pipeline_data_user_policy" {
  statement {
    actions = [
      "s3:PutBucketNotification",
      "s3:ListBucket",
      "s3:GetBucketNotification",
      "s3:GetBucketLocation",
      "s3:ListBucketVersions",
      "s3:GetBucketVersioning"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pipeline_data.id}"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:RestoreObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:ListObjectVersions",
      "s3:GetObjectVersion"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pipeline_data.id}/*"
    ]
  }

  statement {
    actions = [
      "sts:GetFederationToken",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "icav2_pipeline_data_user_policy" {
  name   = "icav2_pipeline_data_user_policy"
  path   = "/icav2/"
  policy = data.aws_iam_policy_document.icav2_pipeline_data_user_policy.json
}