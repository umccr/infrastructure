terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "ica_ens/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.21.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  # Stack name in underscore
  stack_name_us = "ica_ens"

  # Stack name in dash
  stack_name_dash = "ica-ens"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }

  notification_sns_topic_arn = {
    prod = data.aws_sns_topic.chatbot_topic.arn
    dev  = data.aws_sns_topic.chatbot_topic.arn
    stg  = data.aws_sns_topic.chatbot_topic.arn
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_sns_topic" "chatbot_topic" {
  name = "AwsChatBotTopic"
}

# ---
# --- ICA queue for BSSH.RUNS event through ENS subscription
# ---

resource "aws_sqs_queue" "ica_ens_dlq" {
  name = "${local.stack_name_dash}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "ica_ens_queue" {
  name = "${local.stack_name_dash}-queue"
  policy = templatefile("policies/sqs_ica_ens_policy.json", {
    # Use the same name as above, if referring there will be circular dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-queue"
  })
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ica_ens_dlq.arn
    maxReceiveCount = 3
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true

  # Making ICA ENS `bssh.runs` SQS queue to be delayed queue
  # See https://umccr.slack.com/archives/C03ABJTSN7J/p1721685789381979
  delay_seconds = 90

  tags = merge(local.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "ica_ens_sqs_dlq_alarm" {
  alarm_name = "ICAENSEventSQSDLQ"
  alarm_description = "ICA ENS Event SQS DLQ having > 0 messages"
  alarm_actions = [
    local.notification_sns_topic_arn[terraform.workspace]
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
    QueueName = aws_sqs_queue.ica_ens_dlq.name
  }
  tags = merge(local.default_tags)
}
