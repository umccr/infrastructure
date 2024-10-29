################################################################################
# S3 bucket indexing app

variable "s3_primary_data_bucket" {
  default = {
    prod = "umccr-primary-data-prod"
    dev  = "umccr-primary-data-dev"
    stg  = "umccr-primary-data-stg"
  }
  description = "Name of the S3 bucket storing s3 primary data to be used by crawler "
}

variable "s3_run_data_bucket" {
  default = {
    prod = "umccr-run-data-prod"
    dev  = "umccr-run-data-dev"
    stg  = "umccr-run-data-stg"
  }
  description = "Name of the S3 bucket storing s3 run data to be used by crawler "
}

variable "s3_oncoanalyser_bucket" {
  default = {
    prod = "org.umccr.data.oncoanalyser"
    dev  = "umccr-temp-dev"
    stg  = "umccr-temp-stg"
  }
  description = "Name of the S3 bucket storing s3 oncoanalyser output to be used by crawler "
}

variable "s3_icav2_pipeline_cache_bucket" {
  default = {
    prod = "pipeline-prod-cache-503977275616-ap-southeast-2"
    dev  = "pipeline-dev-cache-503977275616-ap-southeast-2"
    stg  = "pipeline-stg-cache-503977275616-ap-southeast-2"
  }
  description = "Name of the S3 bucket from UoM data account for ICAv2 BYOB pipeline cache"
}

data "aws_s3_bucket" "s3_primary_data_bucket" {
  bucket = var.s3_primary_data_bucket[terraform.workspace]
}

data "aws_s3_bucket" "s3_run_data_bucket" {
  bucket = var.s3_run_data_bucket[terraform.workspace]
}

data "aws_s3_bucket" "s3_oncoanalyser_bucket" {
  bucket = var.s3_oncoanalyser_bucket[terraform.workspace]
}

resource "aws_sqs_queue" "s3_event_dlq" {
  name = "${local.stack_name_dash}-${terraform.workspace}-s3-event-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

# SQS Queue for S3 event delivery
resource "aws_sqs_queue" "s3_event_queue" {
  name = "${local.stack_name_dash}-${terraform.workspace}-s3-event-queue"
  policy = templatefile("policies/sqs_s3_primary_data_event_policy.json", {
    # Use the same name as above, if referring there will be circular dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-${terraform.workspace}-s3-event-queue"
    s3_primary_data_bucket_arn = data.aws_s3_bucket.s3_primary_data_bucket.arn
    s3_run_data_bucket_arn = data.aws_s3_bucket.s3_run_data_bucket.arn
    s3_oncoanalyser_arn = data.aws_s3_bucket.s3_oncoanalyser_bucket.arn
    icav2_pipeline_cache_to_sqs_rule_arn = aws_cloudwatch_event_rule.icav2_pipeline_cache_to_sqs_rule.arn
  })
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.s3_event_dlq.arn
    maxReceiveCount = 20
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

# Enable primary data bucket s3 event notification to SQS
resource "aws_s3_bucket_notification" "primary_data_notification" {
  bucket = data.aws_s3_bucket.s3_primary_data_bucket.id

  queue {
    queue_arn = aws_sqs_queue.s3_event_queue.arn

    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
    ]
  }
}

# Enable run data bucket s3 event notification to SQS
resource "aws_s3_bucket_notification" "run_data_notification" {
  bucket = data.aws_s3_bucket.s3_run_data_bucket.id

  queue {
    queue_arn = aws_sqs_queue.s3_event_queue.arn

    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
    ]
  }
}

# Enable oncoanalyser bucket s3 event notification to SQS
resource "aws_s3_bucket_notification" "oncoanalyser_notification" {
  bucket = data.aws_s3_bucket.s3_oncoanalyser_bucket.id

  queue {
    queue_arn = aws_sqs_queue.s3_event_queue.arn

    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*",
    ]

    filter_prefix = "analysis_data/"
  }

  eventbridge = true
}

resource "aws_cloudwatch_metric_alarm" "s3_event_sqs_dlq_alarm" {
  alarm_name = "DataPortalS3EventSQSDLQ"
  alarm_description = "Data Portal S3 Events SQS DLQ having > 0 messages"
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
    QueueName = aws_sqs_queue.s3_event_dlq.name
  }
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "s3_event_sqs_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/s3_event_sqs_arn"
  type  = "String"
  value = aws_sqs_queue.s3_event_queue.arn
  tags  = merge(local.default_tags)
}

# --- ICAv2 pipeline cache bucket subscription
# Meanwhile building OrcaBus and FileManager, we also wish to show `ctTSOv2 pipeline result from ICAv2` in Portal
# Part of the feature story:
#  https://github.com/umccr/infrastructure/issues/434
#  https://github.com/umccr/data-portal-apis/issues/684

resource "aws_cloudwatch_event_rule" "icav2_pipeline_cache_to_sqs_rule" {
  name        = "data-portal-icav2-pipeline-cache-to-portal-s3-sqs"
  description = "Forward S3 events from ICAv2 pipeline cache BYOB bucket to Portal S3 SQS"
  event_pattern = jsonencode({
    source  = ["aws.s3"],
    account = ["503977275616"],  # source contains UoM data account ID
    detail-type: [ "Object Created", "Object Deleted" ],
    detail = {
      bucket = {
        name = [var.s3_icav2_pipeline_cache_bucket[terraform.workspace]]
      },
      object: {
        key: [{ anything-but: { wildcard: "byob-icav2/*/cache/*" }}]
      }
    }
  })

  tags = merge(local.default_tags)
}

resource "aws_cloudwatch_event_target" "icav2_pipeline_cache_to_sqs_target" {
  arn  = aws_sqs_queue.s3_event_queue.arn
  rule = aws_cloudwatch_event_rule.icav2_pipeline_cache_to_sqs_rule.name
}
