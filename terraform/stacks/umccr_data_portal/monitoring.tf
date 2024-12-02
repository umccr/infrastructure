# DEPRECATION:
# Route PortalOps notification to newer alerts-x channels.

####################################################################################
# Notification: CloudWatch alarms send through SNS topic to ChatBot to Slack #data-portal channel
#
# resource "aws_sns_topic" "portal_ops_sns_topic" {
#   name = "DataPortalTopic"
#   display_name = "Data Portal related topics"
#   tags = merge(local.default_tags)
# }
#
# data "aws_iam_policy_document" "portal_ops_sns_topic_policy_doc" {
#   policy_id = "__default_policy_ID"
#
#   statement {
#     actions = [
#       "SNS:GetTopicAttributes",
#       "SNS:SetTopicAttributes",
#       "SNS:AddPermission",
#       "SNS:RemovePermission",
#       "SNS:DeleteTopic",
#       "SNS:Subscribe",
#       "SNS:ListSubscriptionsByTopic",
#       "SNS:Publish",
#       "SNS:Receive",
#     ]
#
#     condition {
#       test     = "StringEquals"
#       variable = "AWS:SourceOwner"
#       values   = [data.aws_caller_identity.current.account_id]
#     }
#
#     effect = "Allow"
#
#     principals {
#       type        = "AWS"
#       identifiers = ["*"]
#     }
#
#     resources = [aws_sns_topic.portal_ops_sns_topic.arn]
#
#     sid = "__default_statement_ID"
#   }
#
#   statement {
#     actions = ["SNS:Publish"]
#
#     principals {
#       type        = "Service"
#       identifiers = ["codestar-notifications.amazonaws.com"]
#     }
#
#     resources = [aws_sns_topic.portal_ops_sns_topic.arn]
#   }
# }
#
# resource "aws_sns_topic_policy" "portal_ops_sns_topic_access_policy" {
#   arn    = aws_sns_topic.portal_ops_sns_topic.arn
#   policy = data.aws_iam_policy_document.portal_ops_sns_topic_policy_doc.json
# }
