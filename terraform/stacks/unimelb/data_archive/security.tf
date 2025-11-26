locals {
  cloudtrail_bucket_name          = "cloudtrail-logs-${local.mgmt_account_id}-${local.region}"
  data_trail_name                 = "dataTrail"
  event_bus_arn_umccr_org_default = "arn:aws:events:ap-southeast-2:${local.account_id_org}:event-bus/default"
}


################################################################################
# Security resources

resource "aws_cloudtrail" "dataTrail" {
  name           = local.data_trail_name
  s3_bucket_name = local.cloudtrail_bucket_name

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }
  tags = merge(
    local.default_tags,
    {
      "umccr:Name" = local.data_trail_name
    }
  )
}


# ------------------------------------------------------------------------------
# EventBridge rule to forward events to the UMCCR org account

data "aws_iam_policy_document" "put_events_to_org_bus" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [local.event_bus_arn_umccr_org_default]
  }
}

resource "aws_iam_policy" "put_events_to_org_bus" {
  name   = "put_events_to_org_bus"
  policy = data.aws_iam_policy_document.put_events_to_org_bus.json
}

resource "aws_iam_role" "put_events_to_org_bus" {
  name               = "put_events_to_org_bus"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy_attachment" "put_events_to_org_bus" {
  role       = aws_iam_role.put_events_to_org_bus.name
  policy_arn = aws_iam_policy.put_events_to_org_bus.arn
}

# TODO: could restrice the events (detail-type) further to avoid unnecessary cost
resource "aws_cloudwatch_event_rule" "put_events_to_org_bus" {
  name        = "put_events_to_org_bus"
  description = "Forward S3 events from IAM Access Analyser to UMCCR org default event bus"
  event_pattern = jsonencode({
    source      = ["aws.access-analyzer", "aws.guardduty"],
    account     = [data.aws_caller_identity.current.account_id],
    detail-type = ["Access Analyzer Finding", "GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "put_events_to_org_bus" {
  target_id = "put_events_to_org_bus"
  arn       = local.event_bus_arn_umccr_org_default
  rule      = aws_cloudwatch_event_rule.put_events_to_org_bus.name
  role_arn  = aws_iam_role.put_events_to_org_bus.arn
}
