/**
 * Schedulers the daily running of the CloudTrail Parquet Lambda, one
 * scheduler for each account.
 */

resource "aws_scheduler_schedule_group" "lambda_function_group" {
  name = "${var.name}-group"
}

# create an event bridge CRON event for each account
resource "aws_scheduler_schedule" "lambda_functions_cron" {
  for_each = toset(var.account_ids)

  name = "${var.name}-${each.key}-twice-daily"
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
      base_input_path  = var.cloudtrail_base_input_path
      base_output_path = var.cloudtrail_base_output_path
      organisation_id  = var.organisation_id
      account_id       = each.key
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
