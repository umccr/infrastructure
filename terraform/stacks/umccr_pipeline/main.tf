terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "umccr_pipeline/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

################################################################################
# Generic resources

provider "aws" {
  # AWS access credentials are retrieved from env variables
  region = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = "${map(
    "Environment", "${terraform.workspace}",
    "Stack", "${var.stack_name}"
  )}"
}

################################################################################
# Setup Lambda requirements

data "template_file" "job_submission_lambda" {
  template = "${file("${path.module}/policies/job-submission-lambda.json")}"

  vars {
    region                             = "${data.aws_region.current.name}"
    account_id                         = "${data.aws_caller_identity.current.account_id}"
    wait_for_async_action_activity_arn = "${aws_sfn_activity.wait_for_async_action.id}"
    ssm_param_prefix                   = "${var.ssm_param_prefix}"
    ssm_role_to_assume_arn             = "${var.ssm_role_to_assume_arn}"
    ssm_run_document_name              = "${var.ssm_run_document_name}"
  }
}

resource "aws_iam_policy" "job_submission_lambda" {
  name   = "${var.stack_name}_job_submission_lambda_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.job_submission_lambda.rendered}"
}

################################################################################
# Setup Lambdas

data "aws_lambda_function" "slack_lambda" {
  function_name = "${var.workspace_notify_slack_lambda_function_name[terraform.workspace]}"
}

module "job_submission_lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "${var.stack_name}_job_submission_lambda_${terraform.workspace}"
  description   = "Lambda to kick off UMCCR pipeline steps."
  runtime       = "python3.6"
  timeout       = 10
  memory_size   = 128

  handler     = "job_submission_lambda.lambda_handler"
  source_path = "${path.module}/lambdas/job_submission_lambda.py"

  attach_policy = true
  policy        = "${aws_iam_policy.job_submission_lambda.arn}"

  environment {
    variables {
      DEPLOY_ENV                         = "${terraform.workspace}"
      WAIT_FOR_ASYNC_ACTION_ACTIVITY_ARN = "${aws_sfn_activity.wait_for_async_action.id}"
      SSM_PARAM_PREFIX                   = "${var.ssm_param_prefix}"
      BASTION_SSM_ROLE_ARN               = "${var.ssm_role_to_assume_arn}"
      SSM_DOC_NAME                       = "${var.ssm_run_document_name}"
    }
  }

  tags = "${merge(
    local.common_tags,
    map(
      "Service", "${var.stack_name}_lambda"
    )
  )}"
}

################################################################################
# AWS Step Functions State Machine

data "template_file" "state_machine_policy" {
  # permission json for the state machine
  template = "${file("${path.module}/policies/state-machine.json")}"

  vars {
    pipeline_lambda_arn                = "${module.job_submission_lambda.function_arn}"
    slack_notify_lambda_arn            = "${data.aws_lambda_function.slack_lambda.arn}"
    wait_for_async_action_activity_arn = "${aws_sfn_activity.wait_for_async_action.id}"
  }
}

resource "aws_iam_policy" "state_machine" {
  # turn permission json into policy
  name   = "${var.stack_name}_state_machine_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.state_machine_policy.rendered}"
}

resource "aws_iam_role" "state_machine" {
  name = "${var.stack_name}_state_machine_${terraform.workspace}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "states.${data.aws_region.current.id}.amazonaws.com"
      }
    },
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS":"arn:aws:iam::383856791668:root"
      }
    }
  ]
}
EOF

  tags = "${local.common_tags}"
}

resource "aws_iam_role_policy_attachment" "state_machine" {
  # attach state machine policy to role
  role       = "${aws_iam_role.state_machine.name}"
  policy_arn = "${aws_iam_policy.state_machine.arn}"
}

resource "aws_sfn_state_machine" "umccr_pipeline" {
  # turn state machine definition into state machine
  name       = "${var.stack_name}_state_machine_${terraform.workspace}"
  role_arn   = "${aws_iam_role.state_machine.arn}"
  definition = "${data.template_file.umccr_pipeline_definition.rendered}"

  tags = "${local.common_tags}"
}

resource "aws_sfn_activity" "wait_for_async_action" {
  # create an activity that's used to block until the async task calls back
  name = "${var.stack_name}_wait_for_async_action_${terraform.workspace}"

  tags = "${local.common_tags}"
}

data "template_file" "umccr_pipeline_definition" {
  # state machine definition json
  template = "${file("state_machines/umccr-pipeline.json")}"

  vars {
    pipeline_lambda_arn                = "${module.job_submission_lambda.function_arn}"
    slack_notify_lambda_arn            = "${data.aws_lambda_function.slack_lambda.arn}"
    wait_for_async_action_activity_arn = "${aws_sfn_activity.wait_for_async_action.id}"
  }
}
