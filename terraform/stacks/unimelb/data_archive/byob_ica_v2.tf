################################################################################
# Local constants

locals {
  # The bucket holding all "active" production data
  pipeline_data_bucket_name      = "${data.aws_caller_identity.current.account_id}-pipeline-cache"
  pipeline_data_bucket_name_prod = "pipeline-prod-cache-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  # The bucket holding all development data
  pipeline_data_bucket_name_dev = "pipeline-dev-cache-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  # The bucket holding all staging data
  pipeline_data_bucket_name_stg = "pipeline-stg-cache-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  # prefix for the BYOB data in ICAv2
  icav2_prefix                    = "byob-icav2/"
  event_bus_arn_umccr_dev_default = "arn:aws:events:ap-southeast-2:${local.account_id_dev}:event-bus/default"
  event_bus_arn_umccr_stg_default = "arn:aws:events:ap-southeast-2:${local.account_id_stg}:event-bus/default"
  # The role that the orcabus file manager uses to ingest events.
  orcabus_file_manager_ingest_role = "orcabus-file-manager-ingest-role"
}


################################################################################
# Buckets

# ==============================================================================
# pipeline cache
# ==============================================================================

resource "aws_s3_bucket" "pipeline_data" {
  bucket = local.pipeline_data_bucket_name

  tags = merge(
    local.default_tags,
    {
      "Name" = local.pipeline_data_bucket_name
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_data" {
  bucket = aws_s3_bucket.pipeline_data.id

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

  bucket = aws_s3_bucket.pipeline_data.id

  rule {
    id     = "base_rule"
    status = "Enabled"
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

# ------------------------------------------------------------------------------
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

# ==============================================================================
# production data
# ==============================================================================

resource "aws_s3_bucket" "production_data" {
  bucket = local.pipeline_data_bucket_name_prod

  tags = merge(
    local.default_tags,
    {
      "Name" = local.pipeline_data_bucket_name_prod
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
  # Must have bucket versioning enabled first to apply noncurrent version expiration
  depends_on = [aws_s3_bucket_versioning.production_data]

  bucket = aws_s3_bucket.production_data.id

  rule {
    id     = "base_rule"
    status = "Enabled"
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
    sid = "prod_lo_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:root"]
    }
    actions = [
      "s3:List*",
      "s3:GetBucketLocation",
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
      identifiers = ["arn:aws:iam::079623148045:role/ica_aps2_crossacct"]
    }
    actions = [
      "s3:PutObject",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.production_data.arn,
      "${aws_s3_bucket.production_data.arn}/*",
    ]
  }
  # statement {
  #   sid = "orcabus_file_manager_ingest_access"
  #   principals {
  #     type        = "AWS"
  #     identifiers = ["arn:aws:iam::${local.account_id_prod}:role/${local.orcabus_file_manager_ingest_role}"]
  #   }
  #   actions = [
  #     "s3:ListBucket",
  #     "s3:GetObject"
  #   ]
  #   resources = [
  #     aws_s3_bucket.production_data.arn,
  #     "${aws_s3_bucket.production_data.arn}/*",
  #   ]
  # }
  statement {
    sid = "data_protal_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_prod}:role/data_portal/data_portal_lambda_apis_role"]
    }
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      aws_s3_bucket.production_data.arn,
      "${aws_s3_bucket.production_data.arn}/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# CORS configuration for ILMN BYO buckets to support UI uploads
# ref: https://help.ica.illumina.com/home/h-storage/s-awss3
resource "aws_s3_bucket_cors_configuration" "production_data" {
  bucket = aws_s3_bucket.production_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["https://ica.illumina.com"]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

# ==============================================================================
# staging data
# ==============================================================================

resource "aws_s3_bucket" "staging_data" {
  bucket = local.pipeline_data_bucket_name_stg

  tags = merge(
    local.default_tags,
    {
      "Name" = local.pipeline_data_bucket_name_stg
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging_data" {
  bucket = aws_s3_bucket.staging_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "staging_data" {
  bucket = aws_s3_bucket.staging_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "staging_data" {
  # Must have bucket versioning enabled first to apply noncurrent version expiration
  depends_on = [aws_s3_bucket_versioning.staging_data]

  bucket = aws_s3_bucket.staging_data.id

  rule {
    id     = "base_rule"
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

resource "aws_s3_bucket_policy" "staging_data" {
  bucket = aws_s3_bucket.staging_data.id
  policy = data.aws_iam_policy_document.staging_data.json
}

data "aws_iam_policy_document" "staging_data" {
  statement {
    sid = "stg_lo_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_stg}:root"]
    }
    actions = [
      "s3:List*",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.staging_data.arn,
      "${aws_s3_bucket.staging_data.arn}/*",
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
      aws_s3_bucket.staging_data.arn,
      "${aws_s3_bucket.staging_data.arn}/*",
    ]
  }
  statement {
    sid = "orcabus_file_manager_ingest_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_stg}:role/${local.orcabus_file_manager_ingest_role}"]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.staging_data.arn,
      "${aws_s3_bucket.staging_data.arn}/*",
    ]
  }
  statement {
    sid = "data_protal_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_stg}:role/data_portal/data_portal_lambda_apis_role"]
    }
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      aws_s3_bucket.staging_data.arn,
      "${aws_s3_bucket.staging_data.arn}/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# CORS configuration for ILMN BYO buckets to support UI uploads
# ref: https://help.ica.illumina.com/home/h-storage/s-awss3
resource "aws_s3_bucket_cors_configuration" "staging_data" {
  bucket = aws_s3_bucket.staging_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["https://ica.illumina.com"]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

# ------------------------------------------------------------------------------
# EventBridge rule to forward events from to the target account

# NOTE: don't control notification settings from TF, as some is controlled by ICA
# resource "aws_s3_bucket_notification" "staging_data" {
#   bucket      = aws_s3_bucket.staging_data.id
#   eventbridge = true
# }

data "aws_iam_policy_document" "put_events_to_stg_bus" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn_umccr_stg_default]
  }
}

resource "aws_iam_policy" "put_events_to_stg_bus" {
  name   = "put_events_to_stg_bus"
  policy = data.aws_iam_policy_document.put_events_to_stg_bus.json
}

resource "aws_iam_role" "put_events_to_stg_bus" {
  name               = "put_events_to_stg_bus"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "put_events_to_stg_bus" {
  role       = aws_iam_role.put_events_to_stg_bus.name
  policy_arn = aws_iam_policy.put_events_to_stg_bus.arn
}

# TODO: could restrict the events (detail-type) further to avoid unnecessary cost
resource "aws_cloudwatch_event_rule" "put_events_to_stg_bus" {
  name        = "put_events_to_stg_bus"
  description = "Forward S3 events from stg bucket to stg event bus"
  event_pattern = jsonencode({
    source  = ["aws.s3"],
    account = [data.aws_caller_identity.current.account_id],
    detail = {
      bucket = {
        name = [aws_s3_bucket.staging_data.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "put_events_to_stg_bus" {
  target_id = "put_events_to_stg_bus"
  arn       = local.event_bus_arn_umccr_stg_default
  rule      = aws_cloudwatch_event_rule.put_events_to_stg_bus.name
  role_arn  = aws_iam_role.put_events_to_stg_bus.arn
}

# ==============================================================================
# development data
# ==============================================================================

resource "aws_s3_bucket" "development_data" {
  bucket = local.pipeline_data_bucket_name_dev

  tags = merge(
    local.default_tags,
    {
      "Name" = local.pipeline_data_bucket_name_dev
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "development_data" {
  bucket = aws_s3_bucket.development_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "development_data" {
  bucket = aws_s3_bucket.development_data.id

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

resource "aws_s3_bucket_policy" "development_data" {
  bucket = aws_s3_bucket.development_data.id
  policy = data.aws_iam_policy_document.development_data.json
}

data "aws_iam_policy_document" "development_data" {
  statement {
    sid = "dev_lo_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_dev}:root"]
    }
    actions = [
      "s3:List*",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.development_data.arn,
      "${aws_s3_bucket.development_data.arn}/*",
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
      aws_s3_bucket.development_data.arn,
      "${aws_s3_bucket.development_data.arn}/*",
    ]
  }
  statement {
    sid = "orcabus_file_manager_ingest_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_dev}:role/${local.orcabus_file_manager_ingest_role}"]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.development_data.arn,
      "${aws_s3_bucket.development_data.arn}/*",
    ]
  }
  statement {
    sid = "data_protal_access"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_dev}:role/data_portal/data_portal_lambda_apis_role"]
    }
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]
    resources = [
      aws_s3_bucket.development_data.arn,
      "${aws_s3_bucket.development_data.arn}/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# CORS configuration for ILMN BYO buckets to support UI uploads
# ref: https://help.ica.illumina.com/home/h-storage/s-awss3
resource "aws_s3_bucket_cors_configuration" "development_data" {
  bucket = aws_s3_bucket.development_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["https://ica.illumina.com"]
    expose_headers  = ["ETag", "x-amz-meta-custom-header"]
    max_age_seconds = 3000
  }
}

# ------------------------------------------------------------------------------
# EventBridge rule to forward events from to the target account

# NOTE: don't control notification settings from TF, as some is controlled by ICA
# resource "aws_s3_bucket_notification" "development_data" {
#   bucket      = aws_s3_bucket.development_data.id
#   eventbridge = true
# }

data "aws_iam_policy_document" "put_events_to_dev_bus" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn_umccr_dev_default]
  }
}

resource "aws_iam_policy" "put_events_to_dev_bus" {
  name   = "put_events_to_dev_bus"
  policy = data.aws_iam_policy_document.put_events_to_dev_bus.json
}

resource "aws_iam_role" "put_events_to_dev_bus" {
  name               = "put_events_to_dev_bus"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "put_events_to_dev_bus" {
  role       = aws_iam_role.put_events_to_dev_bus.name
  policy_arn = aws_iam_policy.put_events_to_dev_bus.arn
}

# TODO: could restrict the events (detail-type) further to avoid unnecessary cost
resource "aws_cloudwatch_event_rule" "put_events_to_dev_bus" {
  name        = "put_events_to_dev_bus"
  description = "Forward S3 events from dev bucket to dev event bus"
  event_pattern = jsonencode({
    source  = ["aws.s3"],
    account = [data.aws_caller_identity.current.account_id],
    detail = {
      bucket = {
        name = [aws_s3_bucket.development_data.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "put_events_to_dev_bus" {
  target_id = "put_events_to_dev_bus"
  arn       = local.event_bus_arn_umccr_dev_default
  rule      = aws_cloudwatch_event_rule.put_events_to_dev_bus.name
  role_arn  = aws_iam_role.put_events_to_dev_bus.arn
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
      "arn:aws:s3:::${aws_s3_bucket.pipeline_data.id}",
      "arn:aws:s3:::${aws_s3_bucket.development_data.id}",
      "arn:aws:s3:::${aws_s3_bucket.staging_data.id}",
      "arn:aws:s3:::${aws_s3_bucket.production_data.id}"
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
      "arn:aws:s3:::${aws_s3_bucket.pipeline_data.id}/*",
      "arn:aws:s3:::${aws_s3_bucket.development_data.id}/*",
      "arn:aws:s3:::${aws_s3_bucket.staging_data.id}/*",
      "arn:aws:s3:::${aws_s3_bucket.production_data.id}/*"
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
