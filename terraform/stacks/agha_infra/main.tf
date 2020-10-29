terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket         = "agha-terraform-states"
    key            = "agha_infra/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = "${map(
    "Environment", "agha",
    "Stack", "${var.stack_name}"
  )}"
}

################################################################################
# S3 buckets

resource "aws_s3_bucket" "agha_gdr_staging" {
  bucket = var.agha_gdr_staging_bucket_name
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    enabled = "1"
    noncurrent_version_expiration {
      days = 30
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload_days = 7
  }

  lifecycle_rule {
    id      = "intelligent_tiering"
    enabled = "1"

    transition {
      storage_class = "INTELLIGENT_TIERING"
    }

    abort_incomplete_multipart_upload_days = 7
  }


  versioning {
    enabled = true
  }

  tags = merge(
    local.common_tags,
    map(
      "Name", var.agha_gdr_staging_bucket_name
    )
  )
}
resource "aws_s3_bucket_public_access_block" "agha_gdr_staging" {
  bucket = aws_s3_bucket.agha_gdr_staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket" "agha_gdr_store" {
  bucket = var.agha_gdr_store_bucket_name
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "noncurrent_version_expiration"
    enabled = true
    noncurrent_version_expiration {
      days = 90
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload_days = 7
  }

  tags = merge(
    local.common_tags,
    map(
      "Name", var.agha_gdr_store_bucket_name
    )
  )

  lifecycle_rule {
    id      = "intelligent_tiering"
    enabled = true

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }

    abort_incomplete_multipart_upload_days = 7
  }
}
resource "aws_s3_bucket_public_access_block" "agha_gdr_store" {
  bucket = aws_s3_bucket.agha_gdr_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Attach bucket policy to deny object deletion
# https://aws.amazon.com/blogs/security/how-to-restrict-amazon-s3-bucket-access-to-a-specific-iam-role/

data "template_file" "store_bucket_policy" {
  template = file("policies/agha_bucket_policy.json")

  vars = {
    bucket_name = aws_s3_bucket.agha_gdr_store.id
    account_id  = data.aws_caller_identity.current.account_id
    role_id     = aws_iam_role.s3_admin_delete.unique_id
  }
}

resource "aws_s3_bucket_policy" "store_bucket_policy" {
  bucket = aws_s3_bucket.agha_gdr_store.id
  policy = data.template_file.store_bucket_policy.rendered
}

data "template_file" "staging_bucket_policy" {
  template = file("policies/agha_bucket_policy.json")

  vars = {
    bucket_name = aws_s3_bucket.agha_gdr_staging.id
    account_id  = data.aws_caller_identity.current.account_id
    role_id     = aws_iam_role.s3_admin_delete.unique_id
  }
}

resource "aws_s3_bucket_policy" "staging_bucket_policy" {
  bucket = aws_s3_bucket.agha_gdr_staging.id
  policy = data.template_file.staging_bucket_policy.rendered
}

################################################################################
# Dedicated IAM role to delete S3 objects (otherwise not allowed)

data "template_file" "saml_assume_policy" {
  template = file("policies/assume_role_saml.json")

  vars = {
    aws_account   = data.aws_caller_identity.current.account_id
    saml_provider = var.saml_provider
  }
}

resource "aws_iam_role" "s3_admin_delete" {
  name                 = "s3_admin_delete"
  path                 = "/"
  assume_role_policy   = data.template_file.saml_assume_policy.rendered
  max_session_duration = "43200"
}

resource "aws_iam_role_policy_attachment" "s3_admin_delete" {
  role       = aws_iam_role.s3_admin_delete.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


################################################################################
# S3 event notification setup

resource "aws_s3_bucket_notification" "bucket_notification_manifest" {
  bucket = aws_s3_bucket.agha_gdr_staging.id

  topic {
    topic_arn     = aws_sns_topic.s3_events.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = "manifest.txt"
  }

  topic {
    topic_arn     = aws_sns_topic.s3_events.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".manifest"
  }
}


data "aws_iam_policy_document" "sns_publish" {
  statement {
    effect = "Allow"

    actions = [
      "SNS:Publish"
    ]

    resources = [
      "arn:aws:sns:*:*:s3_manifest_event",
    ]

    principals {
      type = "AWS"
      identifiers = [
        "*"
      ]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        aws_s3_bucket.agha_gdr_staging.arn
      ]
    }
  }
}

resource "aws_sns_topic" "s3_events" {
  name = "s3_manifest_event"
  policy = data.aws_iam_policy_document.sns_publish.json
}
