#######################################
# General communication resources for the management account
#######################################


#######################################
# SNS Topic + Chatbot for Slack Integration

resource "aws_sns_topic" "biobots_slack" {
  name = "budget-alerts-slack"
}

resource "aws_sns_topic_policy" "biobots_slack" {
  arn = aws_sns_topic.biobots_slack.arn

  policy = data.aws_iam_policy_document.biobots_slack.json
}

data "aws_iam_policy_document" "biobots_slack" {

  statement {
    sid     = "AllowMemberAccountsPublish"
    effect  = "Allow"
    actions = [
      "SNS:Publish"
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [
      aws_sns_topic.biobots_slack.arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = local.member_account_ids
    }
  }
}

# AWS Chatbot configuration for Slack channel

data "aws_ssm_parameter" "slack_channel_id_biobots" {
  name = "/slack/channel-id-biobots"
}

data "aws_ssm_parameter" "slack_team_id" {
  name = "/slack/team-id"
}

resource "aws_chatbot_slack_channel_configuration" "biobots" {
  configuration_name = "biobots-slack-channel"
  slack_team_id      = data.aws_ssm_parameter.slack_team_id.value
  slack_channel_id   = data.aws_ssm_parameter.slack_channel_id_biobots.value

  iam_role_arn  = aws_iam_role.chatbot_assume_role.arn
  logging_level = "INFO"

  # SNS topics linked to this Chatbot configuration
  sns_topic_arns = [ aws_sns_topic.biobots_slack.arn ]
}

# IAM Role for AWS Chatbot
resource "aws_iam_role" "chatbot_assume_role" {
  name = "AWSChatbotAssumeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
      }
    ]
  })
}

# Chatbot IAM Policy (allows CloudWatch logs)
resource "aws_iam_role_policy" "chatbot_biobots_policy" {
  name = "AWSChatbotPolicy-Biobots"
  role = aws_iam_role.chatbot_assume_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/chatbot/*"
      }
    ]
  })
}
