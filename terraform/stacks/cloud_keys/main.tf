terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "cloud_keys/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  # AWS access credentials are retrieved from env variables
  region = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

################################################################################
# AWS lambda 

resource "aws_iam_policy" "lambda_policy" {
  name   = "${var.stack_name}_lambda_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${file("${path.module}/policies/cloud-keys-lambda.json")}"
}

module "cloud_keys_lambda" {
  source = "../../modules/lambda" # based on: https://github.com/claranet/terraform-aws-lambda
  function_name = "${var.stack_name}_lambda_${terraform.workspace}"
  description   = "Lambda for exporting credentials to travis"
  handler       = "cloud_keys.main"
  runtime       = "python3.7"
  timeout       = 900
  source_path = "${path.module}/lambdas/cloud_keys.py"
  attach_policy = true
  policy        = "${aws_iam_policy.lambda_policy.arn}"
  max_session_duration = 43200

  environment {
    variables {
      ENV             = "${terraform.workspace}",
      DURATION        = 3600 #max is 1 hour https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html
      #this is a hack to prevent creating the role myself and passing it into the module
      ROLE_ARN        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud_keys_lambda_${terraform.workspace}" 
      #This is the role that the lambda will export to travis
    }
  }

  tags = {
    service = "${var.stack_name}"
    name    = "${var.stack_name}"
    stack   = "${var.stack_name}"
  }
}

resource "aws_cloudwatch_event_rule" "refresh_cloud_keys" {
  name        = "refresh-cloud-keys"
  description = "refreshes credentials in travis ci"
  schedule_expression = "rate(10 hours)"
}

resource "aws_cloudwatch_event_rule" "every_ten_hours" {
    name = "every-ten-hours"
    description = "Fires every 10 hours"
    schedule_expression = "rate(10 hours)"
}

resource "aws_cloudwatch_event_target" "refresh_creds" {
    rule = "${aws_cloudwatch_event_rule.every_ten_hours.name}"
    target_id = "refresh_creds"
    arn = "${module.cloud_keys_lambda.function_arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${module.cloud_keys_lambda.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.every_ten_hours.arn}"
}


