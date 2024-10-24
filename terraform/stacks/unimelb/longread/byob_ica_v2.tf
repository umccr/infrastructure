################################################################################
# Local constants

#
# NOTE:
# At ICAv2 side, when BYOB bucket that get attached to a project, we should share `storageConfiguration` tenant wide.
# Because in our pipeline input/output preparation, we leverage this API to transition between icav2:// <> s3://
# This is implemented through wrapica library. See https://umccr.slack.com/archives/C03ABJTSN7J/p1722818722795159
#

locals {
  icav2_data_bucket_name_dev       = "byob-longread-${local.this_account_id}-${local.region_sydney}"
  icav2_prefix                     = "byob-icav2/"
  ilmn_cross_account_role          = "arn:aws:iam::079623148045:role/ica_aps2_crossacct"
}


################################################################################
# Buckets


# ==============================================================================
# ICAv2 BYOB data
# ==============================================================================

resource "aws_s3_bucket" "byob_data" {
  provider = aws.sydney
  bucket = local.icav2_data_bucket_name_dev

  tags = merge(
    local.default_tags,
    {
      "Name" = local.icav2_data_bucket_name_dev
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "byob_data" {
  provider = aws.sydney
  bucket = aws_s3_bucket.byob_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "byob_data" {
  provider = aws.sydney
  bucket = aws_s3_bucket.byob_data.id

  rule {
    id     = "base_rule"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "icav2_data_it_rule"
    status = "Enabled"
    filter {
      prefix = local.icav2_prefix
    }
    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_policy" "byob_data" {
  provider = aws.sydney
  bucket = aws_s3_bucket.byob_data.id
  policy = data.aws_iam_policy_document.byob_data.json
}

data "aws_iam_policy_document" "byob_data" {
  provider = aws.sydney
  statement {
    sid = "icav2_cross_account_access"
    principals {
      type        = "AWS"
      identifiers = [local.ilmn_cross_account_role]
    }
    actions = [
      "s3:PutObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.byob_data.arn,
      "${aws_s3_bucket.byob_data.arn}/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# CORS configuration for ILMN BYO buckets
resource "aws_s3_bucket_cors_configuration" "byob_data" {
  provider = aws.sydney
  bucket = aws_s3_bucket.byob_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = [
      "https://ica.illumina.com",     # ILMN UI uploads - https://help.ica.illumina.com/home/h-storage/s-awss3
    ]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

################################################################################
# BYOB IAM User for ICAv2
# ref: https://help.ica.illumina.com/home/h-storage/s-awss3
# NOTE: manipulating IAM user/groups in UoM accounts requires Owner access

resource "aws_iam_user" "icav2_byob_data_admin" {
  provider = aws.sydney
  name = "icav2_byob_data_admin"
  path = "/icav2/"
  tags = local.default_tags
}

resource "aws_iam_group" "icav2" {
  provider = aws.sydney
  name = "icav2"
  path = "/icav2/"
}

resource "aws_iam_group_membership" "icav2" {
  provider = aws.sydney
  name  = "${aws_iam_group.icav2.name}_membership"
  group = aws_iam_group.icav2.name
  users = [
    aws_iam_user.icav2_byob_data_admin.name,
  ]
}

resource "aws_iam_group_policy_attachment" "icav2_group_policy_attachment" {
  provider = aws.sydney
  group      = aws_iam_group.icav2.name
  policy_arn = aws_iam_policy.icav2_byob_data_user_policy.arn
}

data "aws_iam_policy_document" "icav2_byob_data_user_policy" {
  provider = aws.sydney
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
      "arn:aws:s3:::${aws_s3_bucket.byob_data.id}"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:RestoreObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObjectVersion"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.byob_data.id}/*"
    ]
  }

  statement {
    actions = [
      "sts:GetFederationToken",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "icav2_byob_data_user_policy" {
  provider = aws.sydney
  name   = "icav2_byob_data_user_policy"
  path   = "/icav2/"
  policy = data.aws_iam_policy_document.icav2_byob_data_user_policy.json
}
