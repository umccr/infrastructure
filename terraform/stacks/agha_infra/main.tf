terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket         = "agha-terraform-states"
    key            = "infra/terraform.tfstate"
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

# ################################################################################
# # S3 buckets

# resource "aws_s3_bucket" "agha_gdr_staging" {
#   bucket = "${var.agha_gdr_staging_bucket_name}"
#   acl    = "private"

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

#   lifecycle_rule {
#     enabled = "1"
#     noncurrent_version_expiration {
#       days = 30
#     }

#     expiration {
#       expired_object_delete_marker = true
#     }

#     abort_incomplete_multipart_upload_days = 7
#   }

#   lifecycle_rule {
#     id      = "intelligent_tiering"
#     enabled = "1"

#     transition {
#       storage_class = "INTELLIGENT_TIERING"
#     }

#     abort_incomplete_multipart_upload_days = 7
#   }


#   versioning {
#     enabled = true
#   }

#   tags = "${merge(
#     local.common_tags,
#     map(
#       "Name", "${var.agha_gdr_staging_bucket_name}"
#     )
#   )}"
# }
# resource "aws_s3_bucket_public_access_block" "agha_gdr_staging" {
#   bucket = "${aws_s3_bucket.agha_gdr_staging.id}"

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }


# resource "aws_s3_bucket" "agha_gdr_store" {
#   bucket = "${var.agha_gdr_store_bucket_name}"
#   acl    = "private"

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

#   versioning {
#     enabled = true
#   }

#   lifecycle_rule {
#     id      = "noncurrent_version_expiration"
#     enabled = true
#     noncurrent_version_expiration {
#       days = 90
#     }

#     expiration {
#       expired_object_delete_marker = true
#     }

#     abort_incomplete_multipart_upload_days = 7
#   }

#   tags = "${merge(
#     local.common_tags,
#     map(
#       "Name", "${var.agha_gdr_store_bucket_name}"
#     )
#   )}"

#   lifecycle_rule {
#     id      = "intelligent_tiering"
#     enabled = true

#     transition {
#       days          = 0
#       storage_class = "INTELLIGENT_TIERING"
#     }

#     abort_incomplete_multipart_upload_days = 7
#   }
# }
# resource "aws_s3_bucket_public_access_block" "agha_gdr_store" {
#   bucket = "${aws_s3_bucket.agha_gdr_store.id}"

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# # Attach bucket policy to deny object deletion
# # https://aws.amazon.com/blogs/security/how-to-restrict-amazon-s3-bucket-access-to-a-specific-iam-role/

# data "template_file" "store_bucket_policy" {
#   template = "${file("policies/agha_bucket_policy.json")}"

#   vars {
#     bucket_name = "${aws_s3_bucket.agha_gdr_store.id}"
#     account_id  = "${data.aws_caller_identity.current.account_id}"
#     role_id     = "${aws_iam_role.s3_admin_delete.unique_id}"
#   }
# }

# resource "aws_s3_bucket_policy" "store_bucket_policy" {
#   bucket = "${aws_s3_bucket.agha_gdr_store.id}"
#   policy = "${data.template_file.store_bucket_policy.rendered}"
# }

# data "template_file" "staging_bucket_policy" {
#   template = "${file("policies/agha_bucket_policy.json")}"

#   vars {
#     bucket_name = "${aws_s3_bucket.agha_gdr_staging.id}"
#     account_id  = "${data.aws_caller_identity.current.account_id}"
#     role_id     = "${aws_iam_role.s3_admin_delete.unique_id}"
#   }
# }

# resource "aws_s3_bucket_policy" "staging_bucket_policy" {
#   bucket = "${aws_s3_bucket.agha_gdr_staging.id}"
#   policy = "${data.template_file.staging_bucket_policy.rendered}"
# }

# ################################################################################
# # New dataset ready notification (i.e. manifest S3 creation event -> Slack) 

# resource "aws_s3_bucket_notification" "bucket_notification_manifest" {
#   bucket = "${aws_s3_bucket.agha_gdr_staging.id}"

#   topic {
#     topic_arn     = "${aws_sns_topic.s3_events.arn}"
#     events        = ["s3:ObjectCreated:*"]
#     filter_suffix = "manifest.txt"
#   }

#   topic {
#     topic_arn     = "${aws_sns_topic.s3_events.arn}"
#     events        = ["s3:ObjectCreated:*"]
#     filter_suffix = ".manifest"
#   }
# }

# resource "aws_sns_topic" "s3_events" {
#   name = "s3_manifest_event"

#   policy = <<POLICY
# {
#     "Version":"2012-10-17",
#     "Statement":[{
#         "Effect": "Allow",
#         "Principal": {"AWS":"*"},
#         "Action": "SNS:Publish",
#         "Resource": "arn:aws:sns:*:*:s3_manifest_event",
#         "Condition":{
#             "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.agha_gdr_staging.arn}"}
#         }
#     }]
# }
# POLICY
# }

# resource "aws_sns_topic_subscription" "s3_manifest_event" {
#   topic_arn = "${aws_sns_topic.s3_events.arn}"
#   protocol  = "lambda"
#   endpoint  = "${module.notify_slack_lambda.function_arn}"
# }

# resource "aws_sns_topic_subscription" "s3_manifest_event_folder_lock" {
#   topic_arn = "${aws_sns_topic.s3_events.arn}"
#   protocol  = "lambda"
#   endpoint  = "${module.folder_lock_lambda.function_arn}"
# }

# resource "aws_lambda_permission" "slack_lambda_from_sns" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = "${module.notify_slack_lambda.function_name}"
#   principal     = "sns.amazonaws.com"
#   source_arn    = "${aws_sns_topic.s3_events.arn}"
# }

# ################################################################################
# # Lambdas

# # Slack notification lambda
# data "aws_secretsmanager_secret" "slack_webhook_id" {
#   name = "slack/webhook/id"
# }

# data "aws_secretsmanager_secret_version" "slack_webhook_id" {
#   secret_id = "${data.aws_secretsmanager_secret.slack_webhook_id.id}"
# }

# module "notify_slack_lambda" {
#   # based on: https://github.com/claranet/terraform-aws-lambda
#   source = "../../modules/lambda"

#   function_name = "${var.stack_name}_slack_lambda"
#   description   = "Lambda to send messages to Slack"
#   handler       = "notify_slack.lambda_handler"
#   runtime       = "python3.6"
#   timeout       = 3

#   source_path = "${path.module}/lambdas/notify_slack.py"

#   attach_policy = true
#   policy        = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"

#   environment {
#     variables {
#       SLACK_HOST             = "hooks.slack.com"
#       SLACK_WEBHOOK_ENDPOINT = "/services/${data.aws_secretsmanager_secret_version.slack_webhook_id.secret_string}"
#       SLACK_CHANNEL          = "${var.slack_channel}"
#     }
#   }

#   tags = "${merge(
#     local.common_tags,
#     map(
#       "Description", "Lambda to send notifications to UMCCR Slack"
#     )
#   )}"
# }

# # Folder lock lambda
# data "template_file" "folder_lock_lambda" {
#   template = "${file("${path.module}/policies/folder_lock_lambda.json")}"

#   vars {
#     bucket_name = "${aws_s3_bucket.agha_gdr_staging.id}"
#   }
# }

# resource "aws_iam_policy" "folder_lock_lambda" {
#   name   = "${var.stack_name}_folder_lock_lambda_${terraform.workspace}"
#   path   = "/${var.stack_name}/"
#   policy = "${data.template_file.folder_lock_lambda.rendered}"
# }

# module "folder_lock_lambda" {
#   # based on: https://github.com/claranet/terraform-aws-lambda
#   source = "../../modules/lambda"

#   function_name = "${var.stack_name}_folder_lock_lambda"
#   description   = "Lambda to update bucket policy to deny put/delete"
#   handler       = "folder_lock.lambda_handler"
#   runtime       = "python3.7"
#   timeout       = 3

#   source_path = "${path.module}/lambdas/folder_lock.py"

#   attach_policy = true
#   policy        = "${aws_iam_policy.folder_lock_lambda.arn}"

#   tags = "${merge(
#     local.common_tags,
#     map(
#       "Description", "Lambda to update a bucket policy to Deny PutObject/DeleteObject whenever a specific flag file event was triggered"
#     )
#   )}"
# }

# # allow events from SNS topic for manifest notifications
# resource "aws_lambda_permission" "folder_lock_sns_permission" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = "${module.folder_lock_lambda.function_arn}"
#   principal     = "sns.amazonaws.com"
#   source_arn    = "${aws_sns_topic.s3_events.arn}"
# }
