/**
 * Schedulers the daily running of the CloudTrail Parquet Lambda, one
 * scheduler for each account.
 */

resource "aws_scheduler_schedule_group" "lambda_function_group" {
  name = "${var.name}-group"
}

# create an event bridge CRON event for each account
resource "aws_scheduler_schedule" "lambda_functions_cron_yesterday" {
  for_each = toset(var.account_ids)

  name = "${var.name}-${each.key}-yesterdays"
  group_name  = aws_scheduler_schedule_group.lambda_function_group.name

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 50
  }

  # 1 AM and 11PM daily UTC
  # Whilst this doubles the work (cost) it means we can capture
  # late arriving cloudtrail entries - whilst not having to wait
  # too long before _some_ logs appear in the warehouse
  schedule_expression          = "cron(0 1,23 * * ? *)"
  schedule_expression_timezone = "UTC"

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      baseInputPath  = var.cloudtrail_base_input_path
      baseOutputPath = var.cloudtrail_base_output_path
      organisationId  = var.organisation_id
      accountId       = each.key
      processDate     = "yesterday"
    })
  }
}

resource "aws_scheduler_schedule" "lambda_functions_cron_today" {
  for_each = toset(var.account_ids)

  name = "${var.name}-${each.key}-todays"
  group_name  = aws_scheduler_schedule_group.lambda_function_group.name

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 30
  }

  # run 10 past the hour 4 times a day
  # will gradually build up the "day" logs over the day
  # we make sure that 10 + (30 mins flex window) + 15 lambda runtime < 1 hr
  schedule_expression          = "cron(10 0,6,12,18 * * ? *)"
  schedule_expression_timezone = "UTC"

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      baseInputPath  = var.cloudtrail_base_input_path
      baseOutputPath = var.cloudtrail_base_output_path
      organisationId  = var.organisation_id
      accountId       = each.key
      processDate     = "today"
    })
  }
}


# IAM Role for Scheduler
resource "aws_iam_role" "scheduler" {
  name = "scheduler-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Scheduler to invoke Lambda
resource "aws_iam_role_policy" "scheduler_lambda" {
  name = "scheduler-lambda-policy"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.this.arn
      }
    ]
  })
}
