terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "umccrise/terraform.tfstate"
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

  # allow SSH access (during development)
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

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
    stack = "${var.stack_name}"
  }
}

################################################################################
# allow SSH access (during development)
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
  image_id              = "${var.umccrise_image_id}"
  instance_types        = ["m4.large", "m4.xlarge", "m4.2xlarge", "m4.4xlarge", "r3.4xlarge"]
  security_group_ids    = ["${aws_security_group.batch.id}"]
  subnet_ids            = ["${aws_subnet.batch.id}"]
  ec2_additional_policy = "${aws_iam_policy.additionalEc2InstancePolicy.arn}"
  min_vcpus             = 0
  spot_bid_percent      = "100"
}

resource "aws_batch_job_queue" "umccr_batch_queue" {
  name                 = "${var.stack_name}_batch_queue_${terraform.workspace}"
  state                = "ENABLED"
  priority             = 1
  compute_environments = ["${module.compute_env.compute_env_arn}"]
}

## Job definitions

resource "aws_batch_job_definition" "umccrise_standard" {
  name = "${var.stack_name}_job_${terraform.workspace}"
  type = "container"

  parameters = {
    vcpus = 1
  }

  container_properties = "${file("jobs/umccrise_job.json")}"
}

resource "aws_batch_job_definition" "sleeper" {
  name                 = "${var.stack_name}_sleeper_${terraform.workspace}"
  type                 = "container"
  container_properties = "${file("jobs/sleeper_job.json")}"
}

################################################################################
# custom policy for the EC2 instances of the compute env

data "template_file" "additionalEc2InstancePolicy" {
  template = "${file("${path.module}/policies/ec2-instance-role.json")}"

  vars {
    resources = "${jsonencode(var.workspace_umccrise_buckets[terraform.workspace])}"
  }
}

resource "aws_iam_policy" "additionalEc2InstancePolicy" {
  name   = "umccr_batch_additionalEc2InstancePolicy_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.additionalEc2InstancePolicy.rendered}"
}

################################################################################
# AWS lambda 

data "template_file" "lambda" {
  template = "${file("${path.module}/policies/umccrise-lambda.json")}"

  vars {
    resources = "${jsonencode(var.workspace_umccrise_buckets[terraform.workspace])}"
  }
}

resource "aws_iam_policy" "lambda" {
  name   = "${var.stack_name}_lambda_${terraform.workspace}"
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.lambda.rendered}"
}

module "lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "${var.stack_name}_lambda_${terraform.workspace}"
  description   = "Lambda for UMCRISE"
  handler       = "umccrise.lambda_handler"
  runtime       = "python3.6"
  timeout       = 3

  source_path = "${path.module}/lambdas/umccrise.py"

  attach_policy = true
  policy        = "${aws_iam_policy.lambda.arn}"

  environment {
    variables {
      JOBNAME        = "umccrise"
      JOBQUEUE       = "${aws_batch_job_queue.umccr_batch_queue.arn}"
      JOBDEF         = "${aws_batch_job_definition.umccrise_standard.arn}"
      DATA_BUCKET    = "${var.workspace_umccrise_data_bucket[terraform.workspace]}"
      REFDATA_BUCKET = "${var.workspace_umccrise_refdata_bucket[terraform.workspace]}"
    }
  }

  tags = {
    service = "${var.stack_name}"
    name    = "${var.stack_name}"
    stack   = "${var.stack_name}"
  }
}

################################################################################

module "trigger_umccrise_s3_lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "trigger_umccrise_s3_${terraform.workspace}"
  description   = "Lambda for triggering UMCCRISE via s3"
  handler       = "trigger_umccrise_s3.lambda_handler"
  runtime       = "python2.7"
  timeout       = 3

  environment {
    variables {
      UMCCRISE_MEM             = "${var.umccrise_mem[terraform.workspace]}"
      UMCCRISE_VCPUS           = "${var.umccrise_vcpus[terraform.workspace]}"
      UMCCRISE_FUNCTION_NAME   = "${module.lambda.function_name}"
    }
  }

  source_path = "${path.module}/lambdas/trigger_umccrise_s3.py"

  attach_policy = true
  policy        = "${aws_iam_policy.lambda.arn}"

  tags = {
    service = "${var.stack_name}"
    name    = "${var.stack_name}"
    stack   = "${var.stack_name}"
  }
}

resource "aws_lambda_permission" "allow-exec-bucket" {
statement_id = "AllowExecutionFromS3Bucket"
action = "lambda:InvokeFunction"
function_name = "${module.trigger_umccrise_s3_lambda.function_arn}"
principal = "s3.amazonaws.com"
source_arn = "arn:aws:s3:::${var.workspace_umccrise_data_bucket[terraform.workspace]}"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  depends_on = ["aws_lambda_permission.allow-exec-bucket"]
  bucket = "${var.workspace_umccrise_data_bucket[terraform.workspace]}"

  lambda_function {
    lambda_function_arn = "${module.trigger_umccrise_s3_lambda.function_arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = "upload_complete"
  }
}

################################################################################
# CloudWatch Event Rule to match batch events and call Slack lambda

resource "aws_cloudwatch_event_rule" "batch_failure" {
  name        = "${var.stack_name}_capture_batch_job_failure_${terraform.workspace}"
  description = "Capture Batch Job Failures"

  event_pattern = <<PATTERN
{
  "detail-type": [
    "Batch Job State Change"
  ],
  "source": [
    "aws.batch"
  ],
  "detail": {
    "status": [
      "FAILED"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "batch_failure" {
  rule      = "${aws_cloudwatch_event_rule.batch_failure.name}"
  target_id = "${var.stack_name}_send_batch_failure_to_slack_lambda_${terraform.workspace}"
  arn       = "${var.workspace_slack_lambda_arn[terraform.workspace]}"                      # NOTE: the terraform datasource aws_lambda_function appends the version of the lambda to the ARN, which does not seem to work with this! Hence supply the ARN directly.

  input_transformer = {
    input_paths = {
      job    = "$.detail.jobName"
      title  = "$.detail-type"
      status = "$.detail.status"
    }

    # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
    input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
  }
}

resource "aws_lambda_permission" "batch_failure" {
  statement_id  = "${var.stack_name}_allow_batch_failure_to_invoke_slack_lambda_${terraform.workspace}"
  action        = "lambda:InvokeFunction"
  function_name = "${var.workspace_slack_lambda_arn[terraform.workspace]}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.batch_failure.arn}"
}

resource "aws_cloudwatch_event_rule" "batch_success" {
  name        = "${var.stack_name}_capture_batch_job_success_${terraform.workspace}"
  description = "Capture Batch Job Failures"

  event_pattern = <<PATTERN
{
  "detail-type": [
    "Batch Job State Change"
  ],
  "source": [
    "aws.batch"
  ],
  "detail": {
    "status": [
      "SUCCEEDED"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "batch_success" {
  rule      = "${aws_cloudwatch_event_rule.batch_success.name}"
  target_id = "${var.stack_name}_send_batch_success_to_slack_lambda_${terraform.workspace}"
  arn       = "${var.workspace_slack_lambda_arn[terraform.workspace]}"                      # NOTE: the terraform datasource aws_lambda_function appends the version of the lambda to the ARN, which does not seem to work with this! Hence supply the ARN directly.

  input_transformer = {
    input_paths = {
      job    = "$.detail.jobName"
      title  = "$.detail-type"
      status = "$.detail.status"
    }

    # https://serverfault.com/questions/904992/how-to-use-input-transformer-for-cloudwatch-rule-target-ssm-run-command-aws-ru
    input_template = "{ \"topic\": <title>, \"title\": <job>, \"message\": <status> }"
  }
}

resource "aws_lambda_permission" "batch_success" {
  statement_id  = "${var.stack_name}_allow_batch_success_to_invoke_slack_lambda_${terraform.workspace}"
  action        = "lambda:InvokeFunction"
  function_name = "${var.workspace_slack_lambda_arn[terraform.workspace]}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.batch_success.arn}"
}

################################################################################
# AWS API gateway for lambda

resource "aws_api_gateway_rest_api" "lambda_rest_api" {
  name        = "lambda"
  description = "Example API Gateway"
}

resource "aws_api_gateway_resource" "lambda_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.lambda_rest_api.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "lambda_proxy" {
  rest_api_id   = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
  resource_id   = "${aws_api_gateway_resource.lambda_resource.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
  resource_id = "${aws_api_gateway_method.lambda_proxy.resource_id}"
  http_method = "${aws_api_gateway_method.lambda_proxy.http_method}"

  integration_http_method = "${aws_api_gateway_method.lambda_proxy.http_method}"
  type                    = "AWS_PROXY"
  uri                     = "${module.lambda.function_invoke_arn}"

  passthrough_behavior = "WHEN_NO_TEMPLATES"
}

########## 
# Unfortunately the proxy resource cannot match an empty path at the root of the API. 
# To handle that, a similar configuration must be applied to the root resource that 
# is built in to the REST API object:
resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
  resource_id   = "${aws_api_gateway_rest_api.lambda_rest_api.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
  resource_id = "${aws_api_gateway_method.proxy_root.resource_id}"
  http_method = "${aws_api_gateway_method.proxy_root.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${module.lambda.function_invoke_arn}"
}

##########

# resource "aws_api_gateway_method_response" "200" {
#   rest_api_id     = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
#   resource_id     = "${aws_api_gateway_resource.lambda_resource.id}"
#   http_method     = "${aws_api_gateway_method.lambda_proxy.http_method}"
#   status_code     = "200"
#   response_models = {
#     "application/json" = "Empty"
#   }
# }

# resource "aws_api_gateway_integration_response" "lambda_integration_response" {
#   rest_api_id     = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
#   resource_id     = "${aws_api_gateway_resource.lambda_resource.id}"
#   http_method     = "${aws_api_gateway_method.lambda_proxy.http_method}"
#   status_code     = "${aws_api_gateway_method_response.200.status_code}"
#   response_templates {
#     "application/json" = ""
#   }
#   depends_on  = ["aws_api_gateway_integration.lambda_integration"]
# }

resource "aws_lambda_permission" "lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${module.lambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  # source_arn = "${aws_api_gateway_deployment.example.execution_arn}/*/*"
  # source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.lambda_rest_api.id}/*/${aws_api_gateway_method.lambda_proxy.http_method}/lambda"
  source_arn = "${aws_api_gateway_rest_api.lambda_rest_api.execution_arn}/*/*/*"
}

################################################################################

