################################################################################
# Cost Budgets for each UniMelb member account
################################################################################

resource "aws_budgets_budget" "cost_per_account" {
  for_each = local.member_accounts

  name         = "${each.key}-${each.value.account_id}-monthly-cost"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_unit   = "USD"
  limit_amount = tostring(each.value.budget_usd)

  # Filter to a single linked AWS account
  cost_filter {
    name   = "LinkedAccount"
    values = [each.value.account_id]
  }

  # Actual cost > 80% of budget
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [ aws_sns_topic.biobots_slack.arn ]
  }

  # Actual cost > 100% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [ each.value.budget_contact ]
  }
}
