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
  bucket = aws_s3_bucket.analysis_archive.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# TODO: consider adding CloudWatch alarms to monitor object versions
#       NonCurrentVersionObjectCount or NonCurrentVersionStorageBytes (Storage-Lens metrics)
resource "aws_s3_bucket_versioning" "analysis_archive" {
  bucket = aws_s3_bucket.analysis_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "analysis_archive" {

  bucket = aws_s3_bucket.analysis_archive.bucket

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
    id = "archive_instant_access"
    transition {  # move objects to Glacier Instant Retrieval straight away
      days          = 0
      storage_class = "GLACIER_IR"
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "analysis_archive" {
  bucket = aws_s3_bucket.analysis_archive.id
  policy = data.aws_iam_policy_document.analysis_archive.json
}

data "aws_iam_policy_document" "analysis_archive" {
  # Statement to allow FileManager access
  statement {
    sid = "orcabus_file_manager_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:role/${local.orcabus_file_manager_ingest_role}"]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      # Note, filemanager is not using GetObjectAttributes yet.
      "s3:GetObjectAttributes",
      "s3:GetObjectVersionAttributes",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      aws_s3_bucket.analysis_archive.arn,
      "${aws_s3_bucket.analysis_archive.arn}/*",
    ]
  }

  # Allow the data mover access to copy to this bucket.
  statement {
    sid = "orcabus_data_mover_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:role/${local.orcabus_data_mover_role}"]
    }
    actions = [
      # List is needed for aws s3 sync
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      aws_s3_bucket.analysis_archive.arn,
      "${aws_s3_bucket.analysis_archive.arn}/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# EventBridge rule to forward events from to the target account

# NOTE: don't control notification settings from TF, as some is controlled by ICA
# resource "aws_s3_bucket_notification" "analysis_archive" {
#   bucket      = aws_s3_bucket.analysis_archive.id
#   eventbridge = true
# }

data "aws_iam_policy_document" "put_archvie_events_to_prod_bus" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn_umccr_prod_default]
  }
}

resource "aws_iam_policy" "put_archvie_events_to_prod_bus" {
  name   = "put_archvie_events_to_prod_bus"
  policy = data.aws_iam_policy_document.put_archvie_events_to_prod_bus.json
}

resource "aws_iam_role" "put_archvie_events_to_prod_bus" {
  name               = "put_archvie_events_to_prod_bus"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "put_archvie_events_to_prod_bus" {
  role       = aws_iam_role.put_archvie_events_to_prod_bus.name
  policy_arn = aws_iam_policy.put_archvie_events_to_prod_bus.arn
}

# TODO: could restrict the events (detail-type) further to avoid unnecessary cost
resource "aws_cloudwatch_event_rule" "put_archvie_events_to_prod_bus" {
  name        = "put_archvie_events_to_prod_bus"
  description = "Forward S3 events from prod archive bucket to prod event bus"
  event_pattern = jsonencode({
    source  = ["aws.s3"],
    account = [data.aws_caller_identity.current.account_id],
    detail = {
      bucket = {
        name = [aws_s3_bucket.analysis_archive.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "put_archvie_events_to_prod_bus" {
  target_id = "put_archvie_events_to_prod_bus"
  arn       = local.event_bus_arn_umccr_prod_default
  rule      = aws_cloudwatch_event_rule.put_archvie_events_to_prod_bus.name
  role_arn  = aws_iam_role.put_archvie_events_to_prod_bus.arn
}
