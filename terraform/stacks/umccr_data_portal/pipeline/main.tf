terraform {
  required_version = ">= 1.3.3"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "umccr_portal_pipeline/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.38.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  # Stack name in underscore
  stack_name_us = "data_portal"

  # Stack name in dash
  stack_name_dash = "data-portal"

  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name

  ssm_param_key_backend_prefix = "/${local.stack_name_us}/backend"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_sns_topic" "portal_ops_sns_topic" {
  name = "DataPortalTopic"
}

# ---
# --- Portal "main" queues from external services
# --- See https://github.com/umccr/data-portal-apis/blob/dev/docs/model/architecture_code_design.pdf
# ---

# ---
# --- Portal main ICA queue for WES and BSSH through ENS subscription
# ---

resource "aws_sqs_queue" "iap_ens_event_dlq" {
  name = "${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-dlq"
  message_retention_seconds = 1209600
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "iap_ens_event_queue" {
  name = "${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-queue"
  policy = templatefile("policies/sqs_iap_ens_event_policy.json", {
    # Use the same name as above, if referring there will be circular dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-${terraform.workspace}-iap-ens-event-queue"
  })
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.iap_ens_event_dlq.arn
    maxReceiveCount = 3
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6

  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "iap_ens_event_sqs_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/iap_ens_event_sqs_arn"
  type  = "String"
  value = aws_sqs_queue.iap_ens_event_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "ica_ens_event_sqs_dlq_alarm" {
  alarm_name = "DataPortalIAPENSEventSQSDLQ"
  alarm_description = "Data Portal IAP ENS Event SQS DLQ having > 0 messages"
  alarm_actions = [
    data.aws_sns_topic.portal_ops_sns_topic.arn
  ]
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  datapoints_to_alarm = 1
  period = 60
  threshold = 0.0
  namespace = "AWS/SQS"
  statistic = "Sum"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = aws_sqs_queue.iap_ens_event_dlq.name
  }
  tags = merge(local.default_tags)
}

# ---
# --- Portal main queue for tapping into AWS Batch events within account
# ---

resource "aws_sqs_queue" "batch_event_dlq" {
  name                      = "${local.stack_name_dash}-batch-event-dlq"
  message_retention_seconds = 1209600
  tags                      = merge(local.default_tags)
}

resource "aws_sqs_queue" "batch_event_queue" {
  name = "${local.stack_name_dash}-batch-event-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.batch_event_dlq.arn
    maxReceiveCount     = 3
  })

  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags                       = merge(local.default_tags)
}

resource "aws_ssm_parameter" "batch_event_sqs_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/batch_event_sqs_arn"
  type  = "String"
  value = aws_sqs_queue.batch_event_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "batch_event_sqs_dlq_alarm" {
  alarm_name        = "DataPortalBatchEventSQSDLQ"
  alarm_description = "Data Portal Batch Event SQS DLQ having > 0 messages"
  alarm_actions     = [
    data.aws_sns_topic.portal_ops_sns_topic.arn
  ]
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  period              = 60
  threshold           = 0.0
  namespace           = "AWS/SQS"
  statistic           = "Sum"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = {
    QueueName = aws_sqs_queue.batch_event_dlq.name
  }
  tags = merge(local.default_tags)
}
