# ---
# --- Portal "internal" queues for Workflow event control
# --- See https://github.com/umccr/data-portal-apis/blob/dev/docs/model/architecture_code_design.pdf
# ---
# --- For Holmes, it is one way communication such that "fire & forget" from Portal to Holmes pipeline.
# ---

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
