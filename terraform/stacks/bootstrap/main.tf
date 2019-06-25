terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "bootstrap/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  version = "~> 2.4.0"
  region  = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

## Terraform resources #########################################################

# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "dynamodb-terraform-lock" {
  name           = "terraform-state-lock"
  hash_key       = "LockID"
  read_capacity  = 2
  write_capacity = 2

  attribute {
    name = "LockID"
    type = "S"
  }

  tags {
    Name = "Terraform Lock Table"
  }
}

## Instance profile for SSM managed instances ##################################

resource "aws_iam_instance_profile" "AmazonEC2InstanceProfileforSSM" {
  name = "AmazonEC2InstanceProfileforSSM"
  role = "${aws_iam_role.AmazonEC2InstanceProfileforSSM.name}"
}

resource "aws_iam_role" "AmazonEC2InstanceProfileforSSM" {
  name = "AmazonEC2InstanceProfileforSSM"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF

  max_session_duration = "43200"
}

resource "aws_iam_policy" "aws_ec2_ssm" {
  name   = "aws_ec2_ssm${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${file("policies/aws_ec2_ssm.json")}"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2InstanceProfileforSSM" {
  role       = "${aws_iam_role.AmazonEC2InstanceProfileforSSM.name}"
  policy_arn = "${aws_iam_policy.aws_ec2_ssm.arn}"
}

## Roles #######################################################################

data "template_file" "saml_assume_policy" {
  template = "${file("policies/assume_role_from_bastion_and_saml.json")}"

  vars {
    aws_account = "${data.aws_caller_identity.current.account_id}"
  }
}

##### fastq_data_uploader
resource "aws_iam_role" "fastq_data_uploader" {
  name                 = "fastq_data_uploader"
  path                 = "/"
  assume_role_policy   = "${data.template_file.saml_assume_policy.rendered}"
  max_session_duration = "43200"
}

data "template_file" "fastq_data_uploader" {
  template = "${file("policies/fastq_data_uploader.json")}"

  vars {
    resources = "${jsonencode(var.workspace_fastq_data_uploader_buckets[terraform.workspace])}"
  }
}

resource "aws_iam_policy" "fastq_data_uploader" {
  name   = "fastq_data_uploader${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${data.template_file.fastq_data_uploader.rendered}"
}

resource "aws_iam_role_policy_attachment" "fastq_data_uploader" {
  role       = "${aws_iam_role.fastq_data_uploader.name}"
  policy_arn = "${aws_iam_policy.fastq_data_uploader.arn}"
}

##### primary_data_reader
resource "aws_iam_role" "primary_data_reader" {
  name                 = "primary_data_reader"
  path                 = "/"
  assume_role_policy   = "${data.template_file.saml_assume_policy.rendered}"
  max_session_duration = "43200"
}

data "template_file" "primary_data_reader" {
  template = "${file("policies/primary_data_reader.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.primary_data.id}"
  }
}

resource "aws_iam_policy" "primary_data_reader" {
  name   = "primary_data_reader${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${data.template_file.primary_data_reader.rendered}"
}

resource "aws_iam_role_policy_attachment" "primary_data_reader" {
  role       = "${aws_iam_role.primary_data_reader.name}"
  policy_arn = "${aws_iam_policy.primary_data_reader.arn}"
}

##### umccr_worker
resource "aws_iam_role" "umccr_worker" {
  name                 = "umccr_worker"
  path                 = "/"
  assume_role_policy   = "${data.template_file.saml_assume_policy.rendered}"
  max_session_duration = "43200"
}

data "template_file" "umccr_worker" {
  template = "${file("policies/umccr_worker.json")}"

  vars {
    tf_bucket   = "${var.tf_bucket}"
    aws_account = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_iam_policy" "umccr_worker" {
  name   = "umccr_worker${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${data.template_file.umccr_worker.rendered}"
}

resource "aws_iam_role_policy_attachment" "umccr_worker" {
  role       = "${aws_iam_role.umccr_worker.name}"
  policy_arn = "${aws_iam_policy.umccr_worker.arn}"
}

##### umccr_pipeline
resource "aws_iam_role" "umccr_pipeline" {
  name                 = "umccr_pipeline"
  path                 = "/"
  assume_role_policy   = "${file("policies/assume_role_from_bastion.json")}"
  max_session_duration = "43200"
}

data "template_file" "umccr_pipeline" {
  template = "${file("policies/umccr_pipeline.json")}"

  vars {
    aws_account            = "${data.aws_caller_identity.current.account_id}"
    aws_region             = "${data.aws_region.current.name}"
    s3_buckets             = "${jsonencode(var.workspace_fastq_data_uploader_buckets[terraform.workspace])}"
    activity_name          = "${var.workspace_pipeline_activity_name[terraform.workspace]}"
    slack_lambda_name      = "${var.workspace_slack_lambda_name[terraform.workspace]}"
    submission_lambda_name = "${var.workspace_submission_lambda_name[terraform.workspace]}"
    state_machine_name     = "${var.workspace_state_machine_name[terraform.workspace]}"
  }
}

resource "aws_iam_policy" "umccr_pipeline" {
  name   = "umccr_pipeline"
  path   = "/"
  policy = "${data.template_file.umccr_pipeline.rendered}"
}

resource "aws_iam_role_policy_attachment" "umccr_pipeline" {
  role       = "${aws_iam_role.umccr_pipeline.name}"
  policy_arn = "${aws_iam_policy.umccr_pipeline.arn}"
}

## S3 buckets  #################################################################

# S3 bucket for FASTQ data
# NOTE: is meant to be a temporary solution until full support of primary data is there
resource "aws_s3_bucket" "fastq-data" {
  bucket = "${var.workspace_fastq_data_bucket_name[terraform.workspace]}"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "move_to_glacier"
    enabled = "${terraform.workspace == "dev" ? false : true}"

    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# S3 bucket for raw sequencing data
resource "aws_s3_bucket" "raw-sequencing-data" {
  bucket = "${var.workspace_seq_data_bucket_name[terraform.workspace]}"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "move_to_glacier"
    enabled = "${terraform.workspace == "dev" ? false : true}"

    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# S3 bucket to hold primary data
resource "aws_s3_bucket" "primary_data" {
  bucket = "${var.workspace_primary_data_bucket_name[terraform.workspace]}"
  acl    = "private"

  versioning {
    enabled = "${terraform.workspace == "prod" ? true : false}"

    # mfa_delete = true # not supported. see: https://github.com/terraform-providers/terraform-provider-aws/issues/629
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    Name        = "primary-data"
    Environment = "${terraform.workspace}"
  }
}

# S3 bucket as Vault backend store
resource "aws_s3_bucket" "vault" {
  bucket = "${var.workspace_vault_bucket_name[terraform.workspace]}"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    Name        = "vault-data"
    Environment = "${terraform.workspace}"
  }
}

## Slack notify Lambda #########################################################

data "aws_secretsmanager_secret" "slack_webhook_id" {
  name = "slack/webhook/id"
}

data "aws_secretsmanager_secret_version" "slack_webhook_id" {
  secret_id = "${data.aws_secretsmanager_secret.slack_webhook_id.id}"
}

module "notify_slack_lambda" {
  # based on: https://github.com/claranet/terraform-aws-lambda
  source = "../../modules/lambda"

  function_name = "${var.stack_name}_slack_lambda_${terraform.workspace}"
  description   = "Lambda to send messages to Slack"
  handler       = "notify_slack.lambda_handler"
  runtime       = "python3.6"
  timeout       = 3

  source_path = "${path.module}/lambdas/notify_slack.py"

  environment {
    variables {
      SLACK_HOST             = "hooks.slack.com"
      SLACK_WEBHOOK_ENDPOINT = "/services/${data.aws_secretsmanager_secret_version.slack_webhook_id.secret_string}"
      SLACK_CHANNEL          = "${var.workspace_slack_channel[terraform.workspace]}"
    }
  }

  tags = {
    Service     = "${var.stack_name}_lambda"
    Name        = "${var.stack_name}"
    Stack       = "${var.stack_name}"
    Environment = "${terraform.workspace}"
  }
}

## 

# EC2 instance to run Vault server
data "aws_ami" "vault_ami" {
  most_recent      = true
  owners           = ["620123204273"]
  executable_users = ["self"]
  name_regex       = "^vault-ami*"
}

################################################################################
# Set up a main VPC for resources to use
# It'll have with private and public subnets, internet and NAT gateways, etc

module "app_vpc" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-app?ref=v0.5.2"

  vpc_name   = "vpc-${var.stack_name}-main"
  aws_region = "ap-southeast-2"

  cidr_block = "10.2.0.0/18"

  num_nat_gateways = 1

  use_custom_nat_eips = true
  custom_nat_eips     = ["${aws_eip.main_vpc_nat_gateway.id}"]

  custom_tags = {
    Environment = "${terraform.workspace}"
    Stack       = "${var.stack_name}"
  }

  public_subnet_custom_tags = {
    SubnetType = "public"
  }

  private_app_subnet_custom_tags = {
    SubnetType = "private_app"
  }

  private_persistence_subnet_custom_tags = {
    SubnetType = "private_persistence"
  }
}

resource "aws_eip" "main_vpc_nat_gateway" {
  vpc = true

  tags {
    Environment = "${terraform.workspace}"
    Stack       = "${var.stack_name}"
    Name        = "main_vpc_nat_gateway_1_${terraform.workspace}"
  }
}

################################################################################
##     dev only resources                                                     ##
################################################################################

# Add a ops-admin rold that can be assumed without MFA (used for build agents)
resource "aws_iam_role" "ops_admin_no_mfa_role" {
  count                = "${terraform.workspace == "dev" ? 1 : 0}"
  name                 = "ops_admin_no_mfa"
  path                 = "/"
  assume_role_policy   = "${data.template_file.saml_assume_policy.rendered}"
  max_session_duration = "43200"
}

resource "aws_iam_policy" "ops_admin_no_mfa_policy" {
  path   = "/"
  policy = "${file("policies/ops_admin_no_mfa_policy.json")}"
}

resource "aws_iam_role_policy_attachment" "admin_access_to_ops_admin_no_mfa_role_attachment" {
  count      = "${terraform.workspace == "dev" ? 1 : 0}"
  role       = "${aws_iam_role.ops_admin_no_mfa_role.name}"
  policy_arn = "${aws_iam_policy.ops_admin_no_mfa_policy.arn}"
}

resource "aws_eip" "basespace_playground" {
  count = "${terraform.workspace == "dev" ? 1 : 0}"

  tags {
    Name       = "basespace_playground_${terraform.workspace}"
    deploy_env = "${terraform.workspace}"
  }
}

################################################################################
# Dedicated user to generate long lived presigned URLs
# See: https://aws.amazon.com/premiumsupport/knowledge-center/presigned-url-s3-bucket-expiration/

module "presigned_urls" {
  source   = "../../modules/iam_user/secure_user"
  username = "presigned_urls"
  pgp_key  = "keybase:brainstorm"
}

resource "aws_iam_user_policy_attachment" "presigned_user_primary_data" {
  user       = "${module.presigned_urls.username}"
  policy_arn = "${aws_iam_policy.primary_data_reader.arn}"
}

resource "aws_iam_user_policy_attachment" "presigned_user_fastq_data" {
  user       = "${module.presigned_urls.username}"
  policy_arn = "${aws_iam_policy.fastq_data_reader.arn}"
}

data "template_file" "fastq_data_reader" {
  template = "${file("policies/primary_data_reader.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.fastq-data.id}"
  }
}

resource "aws_iam_policy" "fastq_data_reader" {
  name   = "fastq_data_reader_${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${data.template_file.fastq_data_reader.rendered}"
}
