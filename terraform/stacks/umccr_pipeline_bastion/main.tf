terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "umccr_pipeline_bastion/terraform.tfstate"
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
    "Environment", "bastion",
    "Stack", "${var.stack_name}"
  )}"
}

################################################################################
# Get managed instance ID

data "external" "getManagedInstanceId" {
  program = ["${path.module}/scripts/get-managed-instance-id.sh"]
}

################################################################################
# SSM role

resource "aws_iam_role" "ssm_role" {
  name = "${var.stack_name}_ssm_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ssm.amazonaws.com"
      }
    },
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::620123204273:root"
      }
    },
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::472057503814:root"
      }
    }
  ]
}
EOF

  tags = "${local.common_tags}"
}

data "template_file" "ssm_send_command_custom" {
  template = "${file("${path.module}/policies/ssm_send_command_custom.json")}"

  vars {
    ssm_doc_name        = "${aws_ssm_document.umccr_pipeline.name}"
    managed_instance_id = "${data.external.getManagedInstanceId.result.instance_id}"
  }
}

resource "aws_iam_policy" "ssm_send_command" {
  name   = "${var.stack_name}_ssm_send_command_custom"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.ssm_send_command_custom.rendered}"
}

resource "aws_iam_role_policy_attachment" "ssm_send_command_managed" {
  # attach managed AmazonEC2RoleforSSM policy
  role       = "${aws_iam_role.ssm_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "ssm_send_command_custom" {
  # attach custom ssm:SendCommand policy
  role       = "${aws_iam_role.ssm_role.name}"
  policy_arn = "${aws_iam_policy.ssm_send_command.arn}"
}

################################################################################
# Lambda

data "template_file" "async_task_manager_lambda" {
  template = "${file("${path.module}/policies/async_task_manager_lambda.json")}"

  vars {
    dev_sfn_role_arn  = "${var.dev_sfn_role_arn}"
    prod_sfn_role_arn = "${var.prod_sfn_role_arn}"
  }
}

resource "aws_iam_policy" "async_task_manager_lambda" {
  name   = "${var.stack_name}_async_task_manager_lambda"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.async_task_manager_lambda.rendered}"
}

module "async_task_manager_lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "${var.stack_name}_async_task_manager_lambda"
  description   = "Lambda to terminate Step Function tasks on SSM RunCommand events."
  runtime       = "python3.6"
  timeout       = 3
  memory_size   = 128

  handler     = "async_task_manager_lambda.lambda_handler"
  source_path = "${path.module}/lambdas/async_task_manager_lambda.py"

  attach_policy = true
  policy        = "${aws_iam_policy.async_task_manager_lambda.arn}"

  environment {
    variables {
      SSM_DOC_NAME      = "${aws_ssm_document.umccr_pipeline.name}"
      DEV_SFN_ROLE_ARN  = "${var.dev_sfn_role_arn}"
      PROD_SFN_ROLE_ARN = "${var.prod_sfn_role_arn}"
    }
  }

  tags = "${merge(
    local.common_tags,
    map(
      "Service", "${var.stack_name}_lambda"
    )
  )}"
}

resource "aws_lambda_permission" "allow_cloudwatch_event_invoke_lambda" {
  statement_id  = "allow_cloudwatch_event_invoke_lambda"
  action        = "lambda:InvokeFunction"
  function_name = "${module.async_task_manager_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.umccr_pipeline.arn}"
}

################################################################################
# CloudWatch event rule

data "template_file" "cloudwatch_event_rule_pattern" {
  template = "${file("${path.module}/templates/cloudwatch_event_rule_pattern.json")}"

  vars {
    ssm_doc_name = "${aws_ssm_document.umccr_pipeline.name}"
  }
}

resource "aws_cloudwatch_event_rule" "umccr_pipeline" {
  name        = "${var.stack_name}_ssm_command_events"
  description = "Capture SSM RunCommand termination events."

  event_pattern = "${data.template_file.cloudwatch_event_rule_pattern.rendered}"

  depends_on = [
    "module.async_task_manager_lambda"
  ]
}

resource "aws_cloudwatch_event_target" "umccr_pipeline" {
  rule      = "${aws_cloudwatch_event_rule.umccr_pipeline.name}"
  target_id = "InvokeTaskManagerLambda"
  arn       = "${module.async_task_manager_lambda.function_arn}"
}

################################################################################
# Custom SSM RunCommand document

data "local_file" "run_command_document" {
  filename = "${path.module}/templates/UMCCR-RunShellScriptFromStepFunction"
}

resource "aws_ssm_document" "umccr_pipeline" {
  name          = "UMCCR-RunShellScriptFromStepFunction"
  document_type = "Command"

  content = "${data.local_file.run_command_document.content}"

  permissions = {
    type        = "Share"
    account_ids = "${data.aws_caller_identity.current.account_id}"
  }

  tags = "${local.common_tags}"
}
