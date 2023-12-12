################################################################################
# Local constants

locals {
  # The bucket holding all "active" production data
  pipeline_data_bucket_name = "${data.aws_caller_identity.current.account_id}-pipeline-cache"
  # prefix for the "production" project in ICAv2
  icav2_prod_project_prefix = "byob-icav2/production/"
  # prefix for the "staging" project in ICAv2
  icav2_stg_project_prefix = "byob-icav2/staging/"
  # prefix for the "validation-data" project in ICAv2
  icav2_val_project_prefix = "byob-icav2/validation-data/"
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
    id = "prod_data_rule"
    status = "Enabled"
    filter {
      prefix = "${local.icav2_prod_project_prefix}"
    }
    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id = "staging_data_rule"
    status = "Enabled"
    # OZ_IA has minimum storage time of 30 days
    # minimum billable object size of 128 KB
    filter {
      and {
        prefix = "${local.icav2_stg_project_prefix}"
        object_size_greater_than = 128 * 1024
      }
    }
    transition {
      days          = 0
      storage_class = "ONEZONE_IA"
    }
  }
}

resource "aws_s3_bucket_policy" "pipeline_data" {
  bucket = aws_s3_bucket.pipeline_data.id
  policy = data.aws_iam_policy_document.prod_ro_access.json
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
      aws_s3_bucket.pipeline_data.arn,
      "${aws_s3_bucket.pipeline_data.arn}/*",
    ]
  }
}
data "aws_iam_policy_document" "prod_ro_access" {
  statement {
    sid = "basic_access_for_prod"
    principals {
      type        = "AWS"
      identifiers = ["472057503814"]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pipeline_data.id}"
    ]
  }

  statement {
    sid = "icav2_production_ro_access_for_prod"
    principals {
      type        = "AWS"
      identifiers = ["472057503814"]
    }
    actions = [
      "s3:List*",
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pipeline_data.id}/${icav2_prod_project_prefix}*"
    ]
  }

  statement {
    sid = "oa_write_access_for_prod"
    # this should be split into r/o for general use
    # and r/w specifically to OncoAnalyser (roles?)
    principals {
      type        = "AWS"
      identifiers = ["472057503814"]
    }
    actions = [
      "s3:List*",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.pipeline_data.id}/${oa_prod_prefix}*"
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
      "s3:GetBucketLocation"
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
      "s3:DeleteObject"
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