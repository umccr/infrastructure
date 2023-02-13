################################################################################
# Dracarys data tidying app

resource "aws_sqs_queue" "dracarys_ḏlq" {
  name = "${local.stack_name_dash}-dracarys-dlq"
  message_retention_seconds = 1209600
  tags = merge(local.default_tags)
}

resource "aws_sqs_queue" "dracarys_queue" {
  name = "${local.stack_name_dash}-dracarys-event-queue"
  policy = templatefile("policies/dracarys_event_policy.json", {
    # Use the same name as above, if referring there will be circular dependency
    sqs_arn = "arn:aws:sqs:*:*:${local.stack_name_dash}-dracarys-event-queue"
  })
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dracarys_dlq.arn
    maxReceiveCount = 3
  })
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6

  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_dracarys_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_dracarys_queue_arn"
  type  = "String"
  value = aws_sqs_queue.dracarys_event_queue.arn
  tags  = merge(local.default_tags)
}

resource "aws_cloudwatch_metric_alarm" "dracarys_event_dlq_alarm" {
  alarm_name = "DataPortalDracarysEventSQSDLQ"
  alarm_description = "Data Portal Dracarys Event SQS DLQ having > 0 messages"
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
    QueueName = aws_sqs_queue.dracarys_dlq.name
  }
  tags = merge(local.default_tags)
}
