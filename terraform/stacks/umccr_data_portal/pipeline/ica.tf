# ---
# --- Portal "internal" queues for Workflow event control
# --- See https://github.com/umccr/data-portal-apis/blob/dev/docs/model/architecture_code_design.pdf
# ---
# --- For ICA v1, we subscribe to ENS. Details subscription is documented as follows.
# --- https://github.com/umccr/data-portal-apis/tree/dev/docs/pipeline/ica_v1_event
# ---

# --- notification queue

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
