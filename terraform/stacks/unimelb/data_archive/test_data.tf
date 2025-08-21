# Test Data infrastucutre

# NOTE: The test data bucket is set up following the default BYOB setup to allow integration in ICA.
#       As such it depends on configuration from that resource.

locals {
  # The bucket holding all "active" production data
  bucket_name_test_data = "test-data-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  prefix_testdata = "testdata/"
  prefix_input    = "${local.prefix_testdata}input/"
  prefix_output   = "${local.prefix_testdata}analysis/"
}

# ==============================================================================
# test data
# ==============================================================================

resource "aws_s3_bucket" "test_data" {
  bucket = local.bucket_name_test_data

  tags = merge(
    local.default_tags,
    {
      "Name" = local.bucket_name_test_data
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "test_data" {
  bucket = aws_s3_bucket.test_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "test_data" {
  bucket = aws_s3_bucket.test_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "test_data" {
  bucket = aws_s3_bucket.test_data.id

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
      prefix = local.prefix_testdata
    }
    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_policy" "test_data" {
  bucket = aws_s3_bucket.test_data.id
  policy = data.aws_iam_policy_document.test_data.json
}

data "aws_iam_policy_document" "test_data" {
  statement {
    sid = "testdata_ro_access"
    principals {
      type        = "AWS"
      identifiers = [
		"arn:aws:iam::${local.account_id_dev}:root",
		"arn:aws:iam::${local.account_id_stg}:root",
		"arn:aws:iam::${local.account_id_prod}:root"
		]
    }
    actions = sort([
      "s3:ListBucket*",
	    "s3:List*MultiPart*",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:GetObject*Tagging",
      "s3:GetObject*Attributes"
    ])
    resources = sort([
      aws_s3_bucket.test_data.arn,
      "${aws_s3_bucket.test_data.arn}/${local.prefix_testdata}*",
    ])
  }

  statement {
    sid = "test_output_rw_access"
    principals {
      type        = "AWS"
      identifiers = [
		"arn:aws:iam::${local.account_id_dev}:root",
		"arn:aws:iam::${local.account_id_stg}:root",
		"arn:aws:iam::${local.account_id_prod}:root"
		]
    }
    actions = sort([
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:PutObject*Tagging",
      "s3:DeleteObject*Tagging",
    ])
    resources = sort([
      "${aws_s3_bucket.test_data.arn}/${local.prefix_output}*",
    ])
  }

  statement {
     # See https://help.ica.illumina.com/home/h-storage/s-awss3#enabling-cross-account-access-for-copy-and-move-operations
    sid = "icav2_cross_account_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::079623148045:role/ica_aps2_crossacct"]
    }
    actions = sort([
      # Standard actions
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      # Add tagging
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:DeleteObjectTagging",
      "s3:DeleteObjectVersionTagging"
    ])
    resources = sort([
      aws_s3_bucket.test_data.arn,
      "${aws_s3_bucket.test_data.arn}/*",
    ])
  }

}


# ------------------------------------------------------------------------------
# CORS configuration for ILMN BYO buckets
resource "aws_s3_bucket_cors_configuration" "test_data" {
  bucket = aws_s3_bucket.test_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = [
      "https://ica.illumina.com",     # ILMN UI uploads - https://help.ica.illumina.com/home/h-storage/s-awss3
      "https://orcaui.dev.umccr.org", # orcaui - https://github.com/umccr/orca-ui
      "https://portal.dev.umccr.org", # umccr data portal - https://github.com/umccr/umccr-data-portal
    ]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

# ------------------------------------------------------------------------------
# EventBridge rule to forward events from to the target account

# NOTE: don't control notification settings from TF, as some is controlled by ICA
# resource "aws_s3_bucket_notification" "test_data" {
#   bucket      = aws_s3_bucket.test_data.id
#   eventbridge = true
# }

data "aws_iam_policy_document" "put_test_events_to_prod_bus" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn_umccr_prod_default]
  }
}

resource "aws_iam_policy" "put_test_events_to_prod_bus" {
  name   = "put_test_events_to_prod_bus"
  policy = data.aws_iam_policy_document.put_test_events_to_prod_bus.json
}

resource "aws_iam_role" "put_test_events_to_prod_bus" {
  name               = "put_test_events_to_prod_bus"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "put_test_events_to_prod_bus" {
  role       = aws_iam_role.put_test_events_to_prod_bus.name
  policy_arn = aws_iam_policy.put_test_events_to_prod_bus.arn
}

# TODO: could restrict the events (detail-type) further to avoid unnecessary cost
resource "aws_cloudwatch_event_rule" "put_test_events_to_prod_bus" {
  name        = "put_test_events_to_prod_bus"
  description = "Forward S3 events from dev bucket to dev event bus"
  event_pattern = jsonencode({
    source  = ["aws.s3"],
    account = [data.aws_caller_identity.current.account_id],
    detail = {
      bucket = {
        name = [aws_s3_bucket.test_data.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "put_test_events_to_prod_bus" {
  target_id = "put_test_events_to_prod_bus"
  arn       = local.event_bus_arn_umccr_prod_default
  rule      = aws_cloudwatch_event_rule.put_test_events_to_prod_bus.name
  role_arn  = aws_iam_role.put_test_events_to_prod_bus.arn
}


################################################################################
# BYOB IAM User for ICAv2
# ref: https://help.ica.illumina.com/home/h-storage/s-awss3
# NOTE: manipulating IAM user/groups in UoM accounts requires Owner access

resource "aws_iam_user" "icav2_test_data_admin" {
  name = "icav2_test_data_admin"
  path = "/icav2/"
  tags = merge(
    local.default_tags,
    {
      # The Access Key is created manually via Concole, which will add tags to the IAM user.
      # We record this here manually to avoid uncontrolled change of Access Keys
      # (any Access Key change will have to be followed up by tag adjustment)
      "AKIAXKV3C6DQLRER63VF" = "ICA credentials"
    }
  )

}

resource "aws_iam_group" "icav2_test_data_admin" {
  name = "icav2_test_data_admin"
  path = "/icav2/"
}

resource "aws_iam_group_membership" "icav2_test_data_admin" {
  name  = "${aws_iam_group.icav2_test_data_admin.name}_membership"
  group = aws_iam_group.icav2_test_data_admin.name
  users = [
    aws_iam_user.icav2_test_data_admin.name,
  ]
}

resource "aws_iam_group_policy_attachment" "icav2_test_data_admin" {
  group      = aws_iam_group.icav2_test_data_admin.name
  policy_arn = aws_iam_policy.icav2_test_data_admin.arn
}

data "aws_iam_policy_document" "icav2_test_data_admin" {
  statement {
    actions = sort([
      "s3:PutBucketNotification",
      "s3:ListBucket",
      "s3:GetBucketNotification",
      "s3:GetBucketLocation",
      "s3:ListBucketVersions",
      "s3:GetBucketVersioning"
    ])
    resources = sort([
      "arn:aws:s3:::${aws_s3_bucket.test_data.id}"
    ])
  }

  statement {
    actions = sort([
      "s3:PutObject",
      "s3:GetObject",
      "s3:RestoreObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObjectVersion",
      # Add tagging
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:DeleteObjectTagging",
      "s3:DeleteObjectVersionTagging",
    ])
    resources = sort([
      "arn:aws:s3:::${aws_s3_bucket.test_data.id}/*"
    ])
  }

  statement {
    actions = sort([
      "sts:GetFederationToken",
    ])
    resources = ["*"]
  }
}

resource "aws_iam_policy" "icav2_test_data_admin" {
  name   = "icav2_test_data_admin"
  path   = "/icav2/"
  policy = data.aws_iam_policy_document.icav2_test_data_admin.json
}
