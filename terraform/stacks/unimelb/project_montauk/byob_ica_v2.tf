################################################################################
# Local constants

locals {
  # The bucket holding all "active" data from the enclave
  pipeline_data_bucket_name        = "pipeline-montauk-${local.account_id_self}-${local.region}"
  # prefix for the BYOB data in ICAv2
  icav2_prefix                     = "byob-icav2/"
  ilmn_icav2_role                  = "arn:aws:iam::079623148045:role/ica_aps2_crossacct"

  event_bus_arn_umccr_prod_default = "arn:aws:events:ap-southeast-2:${local.account_id_prod}:event-bus/default"

}


################################################################################
# Buckets

# ==============================================================================
# production pipeline data
# ==============================================================================

resource "aws_s3_bucket" "production_data" {
  bucket = local.pipeline_data_bucket_name

  tags = merge(
    local.default_tags,
    {
      "umccr:Name" = local.pipeline_data_bucket_name
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "production_data" {
  bucket = aws_s3_bucket.production_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "production_data" {
  bucket = aws_s3_bucket.production_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "production_data" {
  # Must have bucket versioning enabled first to apply non-current version expiration
  depends_on = [aws_s3_bucket_versioning.production_data]

  bucket = aws_s3_bucket.production_data.id

  rule {
    id     = "base_rule"
    status = "Enabled"

    # NOTE: this causes a Warning. However, it is still an open issue on the provider. Not clear yet what the expected syntax will be.
    # filter {}  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration#specifying-an-empty-filter

    expiration {
      expired_object_delete_marker = true
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
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

resource "aws_s3_bucket_policy" "production_data" {
  bucket = aws_s3_bucket.production_data.id
  policy = data.aws_iam_policy_document.production_data.json
}

data "aws_iam_policy_document" "production_data" {
  statement {
    # Full access to all principals from the UMCCR production account
    # TODO: To be refined if/when needed.
    sid = "umccr_prod_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:root"]
    }
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.production_data.arn,
      "${aws_s3_bucket.production_data.arn}/*",
    ]
  }

  statement {
    sid = "icav2_cross_account_access"
    principals {
      type        = "AWS"
      identifiers = [local.ilmn_icav2_role]
    }
    actions = sort([
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAttributes",
      "s3:GetObjectVersionTagging",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
    ])
    resources = sort([
      aws_s3_bucket.production_data.arn,
      "${aws_s3_bucket.production_data.arn}/*",
    ])
  }

}

# ------------------------------------------------------------------------------
# CORS configuration for ILMN BYO buckets
resource "aws_s3_bucket_cors_configuration" "production_data" {
  bucket = aws_s3_bucket.production_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = [
      "https://ica.illumina.com",       # ILMN UI uploads - https://help.ica.illumina.com/home/h-storage/s-awss3
      "https://orcaui.umccr.org",       # orcaui - https://github.com/umccr/orca-ui
      "https://orcaui.prod.umccr.org",  # orcaui - https://github.com/umccr/orca-ui
      "https://portal.umccr.org",       # orcaui - https://github.com/umccr/orca-ui
    ]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

# ------------------------------------------------------------------------------
# EventBridge rule to forward events from to the target account

# NOTE: We don't control notification settings from TF, as some are controlled by ICA
#       which will interfere with TF management.
#       Instead the EventBridge setting should be enabled manually.
# resource "aws_s3_bucket_notification" "production_data" {
#   bucket      = aws_s3_bucket.production_data.id
#   eventbridge = true
# }

data "aws_iam_policy_document" "put_events_to_prod_bus" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn_umccr_prod_default]
  }
}

resource "aws_iam_policy" "put_events_to_prod_bus" {
  name   = "put_events_to_prod_bus"
  policy = data.aws_iam_policy_document.put_events_to_prod_bus.json
}

resource "aws_iam_role" "put_events_to_prod_bus" {
  name               = "put_events_to_prod_bus"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "put_events_to_prod_bus" {
  role       = aws_iam_role.put_events_to_prod_bus.name
  policy_arn = aws_iam_policy.put_events_to_prod_bus.arn
}

# TODO: could restrict the events (detail-type) further to avoid unnecessary cost
resource "aws_cloudwatch_event_rule" "put_events_to_prod_bus" {
  name        = "put_events_to_prod_bus"
  description = "Forward S3 events from prod bucket to prod event bus"
  event_pattern = jsonencode({
    source  = ["aws.s3"],
    account = [local.account_id_self],
    detail = {
      bucket = {
        name = [aws_s3_bucket.production_data.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "put_events_to_prod_bus" {
  target_id = "put_events_to_prod_bus"
  arn       = local.event_bus_arn_umccr_prod_default
  rule      = aws_cloudwatch_event_rule.put_events_to_prod_bus.name
  role_arn  = aws_iam_role.put_events_to_prod_bus.arn
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
    actions = sort([
      "s3:PutBucketNotification",
      "s3:ListBucket",
      "s3:GetBucketNotification",
      "s3:GetBucketLocation",
      "s3:ListBucketVersions",
      "s3:GetBucketVersioning"
    ])
    resources = sort([
      "arn:aws:s3:::${aws_s3_bucket.production_data.id}"
    ])
  }

  statement {
    actions = sort([
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:RestoreObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      # Add tagging
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:DeleteObjectTagging",
      "s3:DeleteObjectVersionTagging",
    ])
    resources = sort([
      "arn:aws:s3:::${aws_s3_bucket.production_data.id}/*"
    ])
  }

  statement {
    actions = sort([
      "sts:GetFederationToken",
    ])
    resources = ["*"]
  }
}

resource "aws_iam_policy" "icav2_pipeline_data_user_policy" {
  name   = "icav2_pipeline_data_user_policy"
  path   = "/icav2/"
  policy = data.aws_iam_policy_document.icav2_pipeline_data_user_policy.json
}
