################################################################################
# Report ingestion app

resource "aws_sqs_queue" "report_event_dlq" {
  name = "${local.stack_name_dash}-report-event-dlq"
  message_retention_seconds = 1209600
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "report_event_queue" {
  name = "${local.stack_name_dash}-report-event-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.report_event_dlq.arn
    maxReceiveCount = 20
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6

  tags = merge(local.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "report_event_sqs_dlq_alarm" {
  alarm_name = "DataPortalReportEventSQSDLQ"
  alarm_description = "Data Portal Report Events SQS DLQ having > 0 messages"
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
    QueueName = aws_sqs_queue.report_event_dlq.name
  }
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_report_event_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_report_event_queue_arn"
  type  = "String"
  value = aws_sqs_queue.report_event_queue.arn
  tags  = merge(local.default_tags)
}
