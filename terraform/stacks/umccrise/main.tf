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
  image_id              = "${var.workspace_umccrise_image_id[terraform.workspace]}"
  instance_types        = ["m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge"]
  security_group_ids    = ["${aws_security_group.batch.id}"]
  subnet_ids            = ["${aws_subnet.batch.id}"]
  ec2_additional_policy = "${aws_iam_policy.additionalEc2InstancePolicy.arn}"
  min_vcpus             = 0
  max_vcpus             = 160
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

resource "aws_batch_job_definition" "umccrise_standard" {
  name = "${var.stack_name}_job_${terraform.workspace}"
  type = "container"

  parameters = {
    vcpus = 1
  }

  container_properties = "${file("jobs/umccrise_job.json")}"
}

################################################################################
# custom policy for the EC2 instances of the compute env

data "template_file" "additionalEc2InstancePolicy" {
  template = "${file("${path.module}/policies/ec2-instance-role.json")}"

  vars {
    ro_buckets = "${jsonencode(var.workspace_umccrise_ro_buckets[terraform.workspace])}"
    wd_buckets = "${jsonencode(var.workspace_umccrise_wd_buckets[terraform.workspace])}"
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
    resources = "${jsonencode(var.workspace_umccrise_ro_buckets[terraform.workspace])}"
    job_definition_arn = "arn:aws:batch:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:job-definition/${var.job_definition_name}"
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
      JOBNAME_PREFIX = "${var.stack_name}"
      JOBQUEUE       = "${aws_batch_job_queue.umccr_batch_queue.arn}"
      JOBDEF         = "${aws_batch_job_definition.umccrise_standard.arn}"
      REFDATA_BUCKET = "${var.umccrise_refdata_bucket}"
      INPUT_BUCKET    = "${var.workspace_umccrise_data_bucket[terraform.workspace]}"
      UMCCRISE_MEM   = "${var.umccrise_mem[terraform.workspace]}"
      UMCCRISE_VCPUS = "${var.umccrise_vcpus[terraform.workspace]}"
    }
  }

  tags = {
    service = "${var.stack_name}"
    name    = "${var.stack_name}"
    stack   = "${var.stack_name}"
  }
}

################################################################################

