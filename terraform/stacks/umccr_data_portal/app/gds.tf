################################################################################
# GDS files indexing app

resource "aws_sqs_queue" "ica_gds_event_dlq" {
  name = "${local.stack_name_dash}-ica-gds-event-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "ica_gds_event_queue" {
  name = "${local.stack_name_dash}-ica-gds-event-queue"
  policy = templatefile("policies/sqs_ica_gds_event_policy.json", {
    # Use the same name as above, if referring there will be circular dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-ica-gds-event-queue"
  })
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ica_gds_event_dlq.arn
    maxReceiveCount = 3
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true

  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "ica_gds_event_sqs_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/ica_gds_event_sqs_arn"
  type  = "String"
  value = aws_sqs_queue.ica_gds_event_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "ica_gds_event_dlq_alarm" {
  alarm_name = "DataPortalICAGDSEventSQSDLQ"
  alarm_description = "Data Portal ICA GDS Event SQS DLQ having > 0 messages"
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
    QueueName = aws_sqs_queue.ica_gds_event_dlq.name
  }
  tags = merge(local.default_tags)
}
