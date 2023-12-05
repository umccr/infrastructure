terraform {
  required_version = ">= 0.12.6"

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
  common_tags = {
    Environment="agha",
    Stack="${var.stack_name}"
  }
}

################################################################################
# S3 buckets
# Note: changes to public access block requires the temporary detachment of an SCP blocking it on org level

# Staging bucket
resource "aws_s3_bucket" "agha_gdr_staging_2" {
  bucket = var.agha_gdr_staging_2_bucket_name

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
    {
      "Name"=var.agha_gdr_staging_2_bucket_name
    }
  )
}

resource "aws_s3_bucket_public_access_block" "agha_gdr_staging_2" {
  bucket = aws_s3_bucket.agha_gdr_staging_2.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "agha_gdr_staging_2" {
  bucket = aws_s3_bucket.agha_gdr_staging_2.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Store bucket
resource "aws_s3_bucket" "agha_gdr_store_2" {
  bucket = var.agha_gdr_store_2_bucket_name

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
    {
      Name=var.agha_gdr_store_2_bucket_name
    }
  )

  lifecycle_rule {
    id      = "intelligent_tiering"
    enabled = true

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "agha_gdr_store_2" {
  bucket = aws_s3_bucket.agha_gdr_store_2.id

  # Will deep archive all 2022 MM data
  rule {
    status = "Enabled"
    id = "deep_archive_MM_NSWHP_2022"

    filter {
      prefix = "MM_NSWHP/2022"
    }

    transition {
      days = 0
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

  }
  rule {
    status = "Enabled"
    id = "deep_archive_MM_VCGS_2022"
    
    filter {
      prefix = "MM_VCGS/2022"
    }

    transition {
      days = 0
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

}

resource "aws_s3_bucket_public_access_block" "agha_gdr_store_2" {
  bucket = aws_s3_bucket.agha_gdr_store_2.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "agha_gdr_store_2" {
  bucket = aws_s3_bucket.agha_gdr_store_2.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Result bucket
resource "aws_s3_bucket" "agha_gdr_results_2" {
  bucket = var.agha_gdr_results_2_bucket_name
  acl = "private"

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
      days = 30
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload_days = 7
  }

  tags = merge(
    local.common_tags,
    {
      Name=var.agha_gdr_results_2_bucket_name
    }
  )

  lifecycle_rule {
    id      = "intelligent_tiering"
    enabled = true

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "agha_gdr_results_2" {
  bucket = aws_s3_bucket.agha_gdr_results_2.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

##### Archive bucket
resource "aws_s3_bucket" "agha_gdr_archive" {
  bucket = var.agha_gdr_archive_bucket_name
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

  tags = merge(
    local.common_tags,
    {
      "Name"=var.agha_gdr_archive_bucket_name
    }
  )

  lifecycle_rule {
    id      = "deep_archive"
    enabled = true

    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      days = 180
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload_days = 7
  }
}
resource "aws_s3_bucket_public_access_block" "agha_gdr_archive" {
  bucket = aws_s3_bucket.agha_gdr_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
data "template_file" "archive_bucket_policy" {
  template = file("policies/agha_bucket_policy.json")

  vars = {
    bucket_name = aws_s3_bucket.agha_gdr_archive.id
    account_id  = data.aws_caller_identity.current.account_id
    role_id     = aws_iam_role.s3_admin_delete.unique_id
  }
}
resource "aws_s3_bucket_policy" "archive_bucket_policy" {
  bucket = aws_s3_bucket.agha_gdr_archive.id
  policy = data.template_file.archive_bucket_policy.rendered
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
# Lambdas

########################################
# Lambda to send messages to Slack

data "aws_secretsmanager_secret" "slack_webhook_id" {
  name = "slack/webhook/id"
}

data "aws_secretsmanager_secret_version" "slack_webhook_id" {
  secret_id = data.aws_secretsmanager_secret.slack_webhook_id.id
}

module "notify_slack_lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.stack_name}_slack_lambda"
  description   = "Lambda to send messages to Slack"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "./lambdas/notify_slack"

  attach_policy = true
  policy        = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"

  environment_variables = {
      SLACK_HOST             = "hooks.slack.com"
      SLACK_WEBHOOK_ENDPOINT = "/services/${data.aws_secretsmanager_secret_version.slack_webhook_id.secret_string}"
      SLACK_CHANNEL          = var.slack_channel
  }

  tags = merge(
    local.common_tags,
    {
      Name="${var.stack_name}_slack_lambda",
      Description="Lambda to send notifications to UMCCR Slack"
    }
  )
}

################################################################################
# CloudWatch Event Rule to match batch events and call Slack lambda

resource "aws_cloudwatch_event_rule" "batch_failure" {
  name        = "${var.stack_name}_capture_batch_job_failure"
  description = "Capture Batch Job Failures"
  is_enabled = false

  event_pattern = <<PATTERN
{
  "detail-type": [
    "Batch Job State Change"
  ],
  "source": [
    "aws.batch"
  ],
  "detail": {
    "status": [
      "FAILED"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "batch_failure" {
  rule      = aws_cloudwatch_event_rule.batch_failure.name
  target_id = "${var.stack_name}_send_batch_failure_to_slack_lambda"
  arn       = module.notify_slack_lambda.lambda_function_arn

  input_transformer {
    input_paths = {
      job    = "$.detail.jobName"
      title  = "$.detail-type"
      status = "$.detail.status"
    }

    # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
    input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
  }
}

resource "aws_lambda_permission" "batch_failure" {
  statement_id  = "${var.stack_name}_allow_batch_failure_to_invoke_slack_lambda"
  action        = "lambda:InvokeFunction"
  function_name = module.notify_slack_lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.batch_failure.arn
}

# NOTE: SUCCESS events are not supported, as there are too many
#       (success is assumed if there is no failure)
