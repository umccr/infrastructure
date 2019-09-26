terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "wts_report/terraform.tfstate"
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
# networking

resource "aws_security_group" "batch" {
  name   = "${var.stack_name}_batch_compute_environment_security_group_${terraform.workspace}"
  vpc_id = "${aws_vpc.batch.id}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_vpc" "batch" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name  = "${var.stack_name}_vpc_${terraform.workspace}"
    Stack = "${var.stack_name}"
  }
}

resource "aws_subnet" "batch" {
  vpc_id                  = "${aws_vpc.batch.id}"
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.availability_zone}"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "batch" {
  vpc_id = "${aws_vpc.batch.id}"

  tags {
    Name = "${var.stack_name}_gateway_${terraform.workspace}"
  }
}

resource "aws_route_table" "batch" {
  vpc_id = "${aws_vpc.batch.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.batch.id}"
  }
}

resource "aws_route_table_association" "batch" {
  subnet_id      = "${aws_subnet.batch.id}"
  route_table_id = "${aws_route_table.batch.id}"
}

################################################################################
# set up the compute environment
module "compute_env" {
  # NOTE: the source cannot be interpolated, so we can't use a variable here and have to keep the difference bwtween production and developmment in a branch
  source                = "../../modules/batch"
  availability_zone     = "${data.aws_region.current.name}"
  name_suffix           = "_${terraform.workspace}"
  stack_name            = "${var.stack_name}"
  compute_env_name      = "${var.stack_name}_compute_env_${terraform.workspace}"
  image_id              = "${var.workspace_wts_report_image_id[terraform.workspace]}"
  instance_types        = ["m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge"]
  security_group_ids    = ["${aws_security_group.batch.id}"]
  subnet_ids            = ["${aws_subnet.batch.id}"]
  ec2_additional_policy = "${aws_iam_policy.additionalEc2InstancePolicy.arn}"
  min_vcpus             = 0
  max_vcpus             = 80
  use_spot              = "false"
  spot_bid_percent      = "100"
}

resource "aws_batch_job_queue" "umccr_batch_queue" {
  name                 = "${var.stack_name}_batch_queue_${terraform.workspace}"
  state                = "ENABLED"
  priority             = 1
  compute_environments = ["${module.compute_env.compute_env_arn}"]
}

## Job definitions
resource "aws_batch_job_definition" "wts_report" {
  name = "${var.stack_name}_job_${terraform.workspace}"
  type = "container"

  parameters = {
    vcpus = 1
  }

  container_properties = "${file("jobs/wts_report.json")}"
}

################################################################################
# custom policy for the EC2 instances of the compute env

data "template_file" "additionalEc2InstancePolicy" {
  template = "${file("${path.module}/policies/ec2-instance-role.json")}"

  vars {
    resources = "${jsonencode(var.workspace_wts_report_buckets[terraform.workspace])}"
  }
}

resource "aws_iam_policy" "additionalEc2InstancePolicy" {
  name   = "${var.stack_name}_batch_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.additionalEc2InstancePolicy.rendered}"
}

################################################################################
# AWS lambda 

data "template_file" "trigger_lambda" {
  template = "${file("${path.module}/policies/wts_report_trigger_lambda.json")}"

  vars {
    resources = "${jsonencode(var.workspace_wts_report_buckets[terraform.workspace])}"
  }
}

resource "aws_iam_policy" "trigger_lambda" {
  name   = "${var.stack_name}_trigger_lambda_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.trigger_lambda.rendered}"
}

module "trigger_lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "${var.stack_name}_trigger_lambda_${terraform.workspace}"
  description   = "Lambda to trigger RNA report"
  handler       = "trigger_wts_report.lambda_handler"
  runtime       = "python3.7"
  timeout       = 3

  source_path = "${path.module}/lambdas/trigger_wts_report.py"

  attach_policy = true
  policy        = "${aws_iam_policy.trigger_lambda.arn}"

  environment {
    variables {
      JOBNAME_PREFIX = "${var.stack_name}"
      JOBQUEUE       = "${aws_batch_job_queue.umccr_batch_queue.arn}"
      JOBDEF         = "${aws_batch_job_definition.wts_report.arn}"
      DATA_BUCKET    = "${var.workspace_primary_data_bucket[terraform.workspace]}"
      REFDATA_BUCKET = "${var.workspace_refdata_bucket[terraform.workspace]}"
      JOB_MEM        = "${var.umccrise_mem[terraform.workspace]}"
      JOB_VCPUS      = "${var.umccrise_vcpus[terraform.workspace]}"
    }
  }

  tags = {
    service = "${var.stack_name}"
    name    = "${var.stack_name}"
    stack   = "${var.stack_name}"
  }
}

################################################################################
# CloudWatch Event Rule to match batch events and call Slack lambda
# NOTE: those are already covered by the event rules of umccrise


# resource "aws_cloudwatch_event_rule" "batch_failure" {
#   name        = "${var.stack_name}_capture_batch_job_failure_${terraform.workspace}"
#   description = "Capture Batch Job Failures"


#   event_pattern = <<PATTERN
# {
#   "detail-type": [
#     "Batch Job State Change"
#   ],
#   "source": [
#     "aws.batch"
#   ],
#   "detail": {
#     "status": [
#       "FAILED"
#     ]
#   }
# }
# PATTERN
# }


# resource "aws_cloudwatch_event_target" "batch_failure" {
#   rule      = "${aws_cloudwatch_event_rule.batch_failure.name}"
#   target_id = "${var.stack_name}_send_batch_failure_to_slack_lambda_${terraform.workspace}"
#   arn       = "${var.workspace_slack_lambda_arn[terraform.workspace]}"                      # NOTE: the terraform datasource aws_lambda_function appends the version of the lambda to the ARN, which does not seem to work with this! Hence supply the ARN directly.


#   input_transformer = {
#     input_paths = {
#       job    = "$.detail.jobName"
#       title  = "$.detail-type"
#       status = "$.detail.status"
#     }


#     # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
#     input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
#   }
# }


# resource "aws_lambda_permission" "batch_failure" {
#   statement_id  = "${var.stack_name}_allow_batch_failure_to_invoke_slack_lambda_${terraform.workspace}"
#   action        = "lambda:InvokeFunction"
#   function_name = "${var.workspace_slack_lambda_arn[terraform.workspace]}"
#   principal     = "events.amazonaws.com"
#   source_arn    = "${aws_cloudwatch_event_rule.batch_failure.arn}"
# }


# resource "aws_cloudwatch_event_rule" "batch_success" {
#   name        = "${var.stack_name}_capture_batch_job_success_${terraform.workspace}"
#   description = "Capture Batch Job Failures"


#   event_pattern = <<PATTERN
# {
#   "detail-type": [
#     "Batch Job State Change"
#   ],
#   "source": [
#     "aws.batch"
#   ],
#   "detail": {
#     "status": [
#       "SUCCEEDED"
#     ]
#   }
# }
# PATTERN
# }


# resource "aws_cloudwatch_event_target" "batch_success" {
#   rule      = "${aws_cloudwatch_event_rule.batch_success.name}"
#   target_id = "${var.stack_name}_send_batch_success_to_slack_lambda_${terraform.workspace}"
#   arn       = "${var.workspace_slack_lambda_arn[terraform.workspace]}"                      # NOTE: the terraform datasource aws_lambda_function appends the version of the lambda to the ARN, which does not seem to work with this! Hence supply the ARN directly.


#   input_transformer = {
#     input_paths = {
#       job    = "$.detail.jobName"
#       title  = "$.detail-type"
#       status = "$.detail.status"
#     }


#     # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
#     input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
#   }
# }


# resource "aws_lambda_permission" "batch_success" {
#   statement_id  = "${var.stack_name}_allow_batch_success_to_invoke_slack_lambda_${terraform.workspace}"
#   action        = "lambda:InvokeFunction"
#   function_name = "${var.workspace_slack_lambda_arn[terraform.workspace]}"
#   principal     = "events.amazonaws.com"
#   source_arn    = "${aws_cloudwatch_event_rule.batch_success.arn}"
# }


# resource "aws_cloudwatch_event_rule" "batch_submitted" {
#   name        = "${var.stack_name}_capture_batch_job_submit_${terraform.workspace}"
#   description = "Capture Batch Job Submissions"


#   event_pattern = <<PATTERN
# {
#   "detail-type": [
#     "Batch Job State Change"
#   ],
#   "source": [
#     "aws.batch"
#   ],
#   "detail": {
#     "status": [
#       "SUBMITTED"
#     ]
#   }
# }
# PATTERN
# }


# resource "aws_cloudwatch_event_target" "batch_submitted" {
#   rule      = "${aws_cloudwatch_event_rule.batch_submitted.name}"
#   target_id = "${var.stack_name}_send_batch_submitted_to_slack_lambda_${terraform.workspace}"
#   arn       = "${var.workspace_slack_lambda_arn[terraform.workspace]}"                        # NOTE: the terraform datasource aws_lambda_function appends the version of the lambda to the ARN, which does not seem to work with this! Hence supply the ARN directly.


#   input_transformer = {
#     input_paths = {
#       jobid  = "$.detail.jobId"
#       job    = "$.detail.jobName"
#       title  = "$.detail-type"
#       status = "$.detail.status"
#     }


#     # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
#     input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
#   }
# }


# resource "aws_lambda_permission" "batch_submitted" {
#   statement_id  = "${var.stack_name}_allow_batch_submitted_to_invoke_slack_lambda_${terraform.workspace}"
#   action        = "lambda:InvokeFunction"
#   function_name = "${var.workspace_slack_lambda_arn[terraform.workspace]}"
#   principal     = "events.amazonaws.com"
#   source_arn    = "${aws_cloudwatch_event_rule.batch_submitted.arn}"
# }


################################################################################

