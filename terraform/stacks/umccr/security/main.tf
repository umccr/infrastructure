terraform {
  required_version = ">= 1.3.3"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket       = "terraform-state-266735799852-ap-southeast-2"
    key          = "terraform-state/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}

################################################################################
# Generic resources

# Configure the AWS Provider
provider "aws" {
  region = local.region
  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  region          = "ap-southeast-2"
  stack_name      = "security-main"
  account_id_self = data.aws_caller_identity.current.account_id

  default_tags = {
    "Stack"   = local.stack_name
    "Creator" = "Terraform"
    "Project" = "security"
    "Source"  = "https://github.com/umccr/infrastructure/tree/master/terraform/stacks/umccr/security/"
  }

}

################################################################################
# Common resources

data "aws_iam_policy_document" "account_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id_self}:root"]
    }
  }
}

data "aws_iam_policy_document" "chatbot_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

data "aws_secretsmanager_secret" "slack_channel_config" {
  name = "slack/chatbot_channel_config"
}

data "aws_secretsmanager_secret_version" "slack_channel_config" {
  secret_id     = data.aws_secretsmanager_secret.slack_channel_config.id
  version_stage = "AWSCURRENT"
}

################################################################################
# Security Hub CSPM controls
# https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-cis-controls.html

# IAM.18
# https://docs.aws.amazon.com/securityhub/latest/userguide/iam-controls.html#iam-18
resource "aws_iam_role" "aws_support_access" {
  name               = "aws_support_access"
  path               = "/${local.stack_name}/"
  assume_role_policy = data.aws_iam_policy_document.account_assume_role_policy.json

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "aws_support_access" {
  role       = aws_iam_role.aws_support_access.name
  policy_arn = "arn:aws:iam::aws:policy/AWSSupportAccess"
}


################################################################################
# Slack Notifications via Chatbot
# NOTE: the AWS account first needs to be authorised for the Slack workspace
#       Go to the Chatbot / Amazon Q console and "Configure new client"


resource "aws_sns_topic" "security_notifications" {
  name_prefix  = "security_notifications"
  display_name = "security_notifications"

  tags = local.default_tags
}

resource "aws_sns_topic_policy" "security_notifications" {
  arn    = aws_sns_topic.security_notifications.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    sid    = "__default_statement_ID"
    effect = "Allow"
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [
      aws_sns_topic.security_notifications.arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        local.account_id_self,
      ]
    }
  }

  statement {
    sid    = "AllowEventBridgeToPublish"
    effect = "Allow"
    actions = [
      "SNS:Publish"
    ]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [
      aws_sns_topic.security_notifications.arn,
    ]
  }
}

data "aws_iam_policy_document" "security_notifications" {
  statement {
    effect = "Allow"
    actions = sort([
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*"
    ])
    resources = ["*"]
  }
}

resource "aws_iam_policy" "security_notifications" {
  name   = "security_notifications"
  policy = data.aws_iam_policy_document.security_notifications.json
}

resource "aws_iam_role" "security_notifications" {
  name               = "security_notifications"
  path               = "/${local.stack_name}/"
  assume_role_policy = data.aws_iam_policy_document.chatbot_assume_role_policy.json

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "security_notifications" {
  role       = aws_iam_role.security_notifications.name
  policy_arn = aws_iam_policy.security_notifications.arn
}

resource "aws_chatbot_slack_channel_configuration" "security_notifications" {
  configuration_name    = "security_notifications"
  iam_role_arn          = aws_iam_role.security_notifications.arn
  slack_channel_id      = jsondecode(data.aws_secretsmanager_secret_version.slack_channel_config.secret_string)["channel_id"]
  slack_team_id         = jsondecode(data.aws_secretsmanager_secret_version.slack_channel_config.secret_string)["workspace_id"]
  guardrail_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  sns_topic_arns        = [aws_sns_topic.security_notifications.arn]

  tags = merge(
    local.default_tags,
    {
      "Name" = "security_notifications"
    }
  )
}

####
# EventBridge
# Set up an event rule for IAM Access Analyser Findings and route them to Chatbot

# data "aws_iam_policy_document" "security_event_routing" {
#   statement {
#     effect    = "Allow"
#     actions   = ["events:PutEvents"]
#     resources = [data.aws_cloudwatch_event_bus.default.arn]
#   }
# }

# resource "aws_iam_policy" "security_event_routing" {
#   name   = "security_event_routing"
#   policy = data.aws_iam_policy_document.security_event_routing.json
# }

# resource "aws_iam_role" "security_event_routing" {
#   name               = "security_event_routing"
#   assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "security_event_routing" {
#   role       = aws_iam_role.security_event_routing.name
#   policy_arn = aws_iam_policy.security_event_routing.arn
# }

resource "aws_cloudwatch_event_rule" "security_event_routing" {
  name        = "security_event_routing"
  description = "Forward IAM Access Analyser events to the SNS topic for Chatbot / Slack"
  event_pattern = jsonencode({
    source      = ["aws.access-analyzer"],
    detail-type = ["Access Analyzer Finding"]
    detail = {
      isDeleted = [false]
    }
  })
}

resource "aws_cloudwatch_event_target" "security_event_routing" {
  #   target_id = "security_event_routing"
  target_id = aws_cloudwatch_event_rule.security_event_routing.id
  arn       = aws_sns_topic.security_notifications.arn
  rule      = aws_cloudwatch_event_rule.security_event_routing.name
  #   role_arn  = aws_iam_role.security_event_routing.arn

  input_transformer {
    input_paths = {
      "eventAccountId": "$.account",
      "accountId" : "$.detail.accountId",
      "action" : "$.detail.action",
      "id" : "$.detail.id",
      "principal" : "$.detail.principal.AWS",
      "resource" : "$.detail.resource",
      "resourceType" : "$.detail.resourceType"
    }

    # Example: https://umccr.slack.com/archives/C06T9S6DZKK/p1764022823299979
    input_template = jsondecode({
      "version" : "1.0",
      "source" : "custom",
      "content" : {
        "textType" : "client-markdown",
        "title" : "Access Analyzer Finding - UMCCR (<eventAccountId>)",
        "description" : "*CONTEXT* \n• Finding ID: `<id>`\n• Account ID: `<accountId>`\n\n*RESOURCE*\n• Type: `<resourceType>`\n• ARN: `<resource>`\n\n*ACCESS DETAILS*\n• Principal (AWS Account): `<principal>`"
      }
    })
  }

}

