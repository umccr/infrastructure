# ---
# --- Portal "internal" queues for Workflow event control
# --- See https://github.com/umccr/data-portal-apis/blob/dev/docs/model/architecture_code_design.pdf
# ---
# --- For oncoanalyser, we subscribe to AWS Batch event.
# --- See diagram in https://umccr.slack.com/archives/CP356DDCH/p1693195057311949
# ---

locals {
  event_bus_name = "default"
}

# --- Oncoanalyser Event Rule and Target
# See https://umccr.slack.com/archives/CP356DDCH/p1693207009752899

resource "aws_cloudwatch_event_rule" "oncoanalyser" {
  name           = "${local.stack_name_dash}-oncoanalyser-batch-event-rule"
  description    = "Portal subscribes to Oncoanalyser Batch Event Rule"
  event_bus_name = local.event_bus_name
  is_enabled     = true
  event_pattern  = jsonencode({
    detail-type = [
      "Batch Job State Change"
    ],
    source = ["aws.batch"],
    detail = {
      "status" : [
        "STARTING",
        "RUNNING",
        "SUCCEEDED",
        "FAILED"
      ],
      "jobQueue" : [
        { "prefix" : "arn:aws:batch:${local.region}:${local.account_id}:job-queue/nextflow-pipeline" }
      ],
    }
  })
  tags = merge(local.default_tags)
}

resource "aws_cloudwatch_event_target" "oncoanalyser" {
  event_bus_name = local.event_bus_name
  rule           = aws_cloudwatch_event_rule.oncoanalyser.name
  arn            = aws_sqs_queue.batch_event_queue.arn  # send it to Portal Bach Event SQS
}

# --- star alignment queue

resource "aws_sqs_queue" "star_alignment_queue" {
  name = "${local.stack_name_dash}-star-alignment-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_star_alignment_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_star_alignment_queue_arn"
  type  = "String"
  value = aws_sqs_queue.star_alignment_queue.arn
  tags  = merge(local.default_tags)
}

# --- oncoanalyser wts queue

resource "aws_sqs_queue" "oncoanalyser_wts_queue" {
  name = "${local.stack_name_dash}-oncoanalyser-wts-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_oncoanalyser_wts_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_oncoanalyser_wts_queue_arn"
  type  = "String"
  value = aws_sqs_queue.oncoanalyser_wts_queue.arn
  tags  = merge(local.default_tags)
}

# --- oncoanalyser wgs queue

resource "aws_sqs_queue" "oncoanalyser_wgs_queue" {
  name = "${local.stack_name_dash}-oncoanalyser-wgs-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_oncoanalyser_wgs_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_oncoanalyser_wgs_queue_arn"
  type  = "String"
  value = aws_sqs_queue.oncoanalyser_wgs_queue.arn
  tags  = merge(local.default_tags)
}

# --- oncoanalyser wgts queue

resource "aws_sqs_queue" "oncoanalyser_wgts_queue" {
  name = "${local.stack_name_dash}-oncoanalyser-wgts-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_oncoanalyser_wgts_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_oncoanalyser_wgts_queue_arn"
  type  = "String"
  value = aws_sqs_queue.oncoanalyser_wgts_queue.arn
  tags  = merge(local.default_tags)
}

# --- sash queue

resource "aws_sqs_queue" "sash_queue" {
  name = "${local.stack_name_dash}-sash-queue.fifo"
  fifo_queue = true
  content_based_deduplication = true
  visibility_timeout_seconds = 30*6  # lambda function timeout * 6
  sqs_managed_sse_enabled = true
  tags = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sqs_sash_queue_arn" {
  name  = "${local.ssm_param_key_backend_prefix}/sqs_sash_queue_arn"
  type  = "String"
  value = aws_sqs_queue.sash_queue.arn
  tags  = merge(local.default_tags)
}
