################################################################################
# Local constants

locals {
  # The bucket holding all archived FASTQ data
  # fastq_archive_bucket_name = "${data.aws_caller_identity.current.account_id}-fastq-archive"
  fastq_archive_bucket_name = "archive-prod-fastq-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  # The role that the https://github.com/umccr/steps-s3-copy stack for data restore and data sharing
  steps_s3_copy_restore_share_role = "umccr-wehi-data-sharing-role"  # FIXME to be changed it to a more permanent data sharing role in future
  steps_s3_copy_restore_share_role_dev = "steps-s3-copy-role"  # FIXME to be changed / merged to a more permanent data sharing role in future
}

################################################################################
# Buckets

resource "aws_s3_bucket" "fastq_archive" {
  bucket = local.fastq_archive_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name"=local.fastq_archive_bucket_name,
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fastq_archive" {
  bucket = aws_s3_bucket.fastq_archive.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "fastq_archive" {
  bucket = aws_s3_bucket.fastq_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "fastq_archive" {

  bucket = aws_s3_bucket.fastq_archive.bucket

  rule {
    id = "base_rule"
    status = "Enabled"
    expiration {
      expired_object_delete_marker = true
    }
    noncurrent_version_expiration {
      # Lowest storage tier is currently: GLACIER_IR
      # It's charged for a min of 90 days (DEEP_ARCHIVE = 180 days)
      noncurrent_days = 85
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id = "deep_archive_greater_5mb"
    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }
    filter {
      object_size_greater_than = 5000000
    }
    status = "Enabled"
  }

  rule {
    id = "archive_instant_less_5mb"
    transition {
      days          = 0
      storage_class = "GLACIER_IR"
    }
    filter {
      object_size_less_than = 5000000
      # Confirmed. This is implicitly taken care of by AWS. Keeping note here as doc purpose.
      #     > Starting September 2024, the default behavior prevents objects smaller
      #     > than 128 KB from being transitioned to any storage class.
      # See https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html
      # object_size_greater_than = 150000
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "fastq_archive" {
  bucket = aws_s3_bucket.fastq_archive.id
  policy = data.aws_iam_policy_document.fastq_archive.json
}

data "aws_iam_policy_document" "fastq_archive" {
  # Statement to allow FileManager access
  statement {
    sid = "orcabus_file_manager_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:role/${local.orcabus_file_manager_ingest_role}"]
    }
    actions = sort([
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetObject",
      # Note, filemanager is not using GetObjectAttributes yet.
      "s3:GetObjectAttributes",
      "s3:GetObjectVersionAttributes",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ])
    resources = sort([
      aws_s3_bucket.fastq_archive.arn,
      "${aws_s3_bucket.fastq_archive.arn}/*"
    ])
  }

  statement {
    sid = "orcabus_file_manager_presign_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:user/${local.orcabus_file_manager_presign_user}"]
    }
    actions = sort([
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetObject",
    ])
    resources = sort([
      aws_s3_bucket.fastq_archive.arn,
      "${aws_s3_bucket.fastq_archive.arn}/*",
    ])
  }

  # Allow the data mover access to copy to this bucket.
  statement {
    sid = "orcabus_data_mover_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:role/${local.orcabus_data_mover_role}"]
    }
    actions = sort([
      # List is needed for aws s3 sync
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ])
    resources = sort([
      aws_s3_bucket.fastq_archive.arn,
      "${aws_s3_bucket.fastq_archive.arn}/*"
    ])
  }

  # Allow the steps-s3-copy role to restore and read to this bucket.
  statement {
    sid = "steps_s3_copy_restore_share_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:role/${local.steps_s3_copy_restore_share_role}"]
    }
    actions = sort([
      # List is needed for aws s3 sync
      "s3:ListBucket",
      "s3:RestoreObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectAttributes",
      "s3:GetObjectVersionAttributes",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
    ])
    resources = sort([
      aws_s3_bucket.fastq_archive.arn,
      "${aws_s3_bucket.fastq_archive.arn}/*"
    ])
  }

  # Statement to allow access to any principal from the prod account
  statement {
	  sid = "umccr_prod_account_access"
    principals {
      type        = "AWS"
      identifiers = ["472057503814"]
    }
    actions = sort([
      "s3:List*",
      "s3:GetObjectTagging"
    ])
    resources = sort([
      aws_s3_bucket.fastq_archive.arn,
      "${aws_s3_bucket.fastq_archive.arn}/*"
    ])
  }
}

# ------------------------------------------------------------------------------
# EventBridge rule to forward events from to the target account

resource "aws_s3_bucket_notification" "fastq_archive" {
  bucket      = aws_s3_bucket.fastq_archive.id
  eventbridge = true
}

data "aws_iam_policy_document" "put_fastq_events_to_prod_bus" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn_umccr_prod_default]
  }
}

resource "aws_iam_policy" "put_fastq_events_to_prod_bus" {
  name   = "put_fastq_events_to_prod_bus"
  policy = data.aws_iam_policy_document.put_fastq_events_to_prod_bus.json
}

resource "aws_iam_role" "put_fastq_events_to_prod_bus" {
  name               = "put_fastq_events_to_prod_bus"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "put_fastq_events_to_prod_bus" {
  role       = aws_iam_role.put_fastq_events_to_prod_bus.name
  policy_arn = aws_iam_policy.put_fastq_events_to_prod_bus.arn
}

# TODO: could restrict the events (detail-type) further to avoid unnecessary cost
resource "aws_cloudwatch_event_rule" "put_fastq_events_to_prod_bus" {
  name        = "put_fastq_events_to_prod_bus"
  description = "Forward S3 events from prod fastq archive bucket to prod event bus"
  event_pattern = jsonencode({
    source  = ["aws.s3"],
    account = [data.aws_caller_identity.current.account_id],
    detail = {
      bucket = {
        name = [aws_s3_bucket.fastq_archive.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "put_fastq_events_to_prod_bus" {
  target_id = "put_fastq_events_to_prod_bus"
  arn       = local.event_bus_arn_umccr_prod_default
  rule      = aws_cloudwatch_event_rule.put_fastq_events_to_prod_bus.name
  role_arn  = aws_iam_role.put_fastq_events_to_prod_bus.arn
}
