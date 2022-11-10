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

  ssm_param_key_backend_prefix = "/${local.stack_name_us}/backend"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }
}

data "aws_sns_topic" "portal_ops_sns_topic" {
  name = "DataPortalTopic"
}

# --- main queue

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

# --- batch notification queue

resource "aws_sqs_queue" "notification_queue" {
  name = "${local.stack_name_dash}-notification-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  delay_seconds = 5
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_notification_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_notification_queue_arn"
  type  = "String"
  value = aws_sqs_queue.notification_queue.arn
  tags  = merge(local.default_tags)
}

# --- wgs qc queue

resource "aws_sqs_queue" "dragen_wgs_qc_queue" {
  name = "${local.stack_name_dash}-dragen-wgs-qc-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_dragen_wgs_qc_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_dragen_wgs_qc_queue_arn"
  type  = "String"
  value = aws_sqs_queue.dragen_wgs_qc_queue.arn
  tags  = merge(local.default_tags)
}

# --- tso ctdna queue

resource "aws_sqs_queue" "dragen_tso_ctdna_queue" {
  name = "${local.stack_name_dash}-dragen-tso-ctdna-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_dragen_tso_ctdna_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_dragen_tso_ctdna_queue_arn"
  type  = "String"
  value = aws_sqs_queue.dragen_tso_ctdna_queue.arn
  tags  = merge(local.default_tags)
}

# --- tumor normal queue

resource "aws_sqs_queue" "tn_queue" {
  name = "${local.stack_name_dash}-tn-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_tn_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_tumor_normal_queue_arn"
  type  = "String"
  value = aws_sqs_queue.tn_queue.arn
  tags  = merge(local.default_tags)
}

# --- wts queue

resource "aws_sqs_queue" "dragen_wts_queue" {
  name = "${local.stack_name_dash}-dragen-wts-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_dragen_wts_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_dragen_wts_queue_arn"
  type  = "String"
  value = aws_sqs_queue.dragen_wts_queue.arn
  tags  = merge(local.default_tags)
}

# --- umccrise queue

resource "aws_sqs_queue" "umccrise_queue" {
  name = "${local.stack_name_dash}-umccrise-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_umccrise_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_umccrise_queue_arn"
  type  = "String"
  value = aws_sqs_queue.umccrise_queue.arn
  tags  = merge(local.default_tags)
}

# --- rnasum queue

resource "aws_sqs_queue" "rnasum_queue" {
  name = "${local.stack_name_dash}-rnasum-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_rnasum_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_rnasum_queue_arn"
  type  = "String"
  value = aws_sqs_queue.rnasum_queue.arn
  tags  = merge(local.default_tags)
}

# --- somalier extract queue
resource "aws_sqs_queue" "somalier_extract_queue" {
  name = "${local.stack_name_dash}-somalier_extract-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_somalier_extract_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_somalier_extract_queue_arn"
  type  = "String"
  value = aws_sqs_queue.somalier_extract_queue.arn
  tags  = merge(local.default_tags)
}