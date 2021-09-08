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
  name   = "aws_ec2_ssm_${terraform.workspace}"
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
    s3_buckets             = "${jsonencode(var.workspace_umccr_pipeline_write_buckets[terraform.workspace])}"
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
resource "aws_s3_bucket" "fastq_data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
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
resource "aws_s3_bucket_public_access_block" "fastq_data" {
  bucket = "${aws_s3_bucket.fastq_data.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "template_file" "fastq_data_bucket_policy" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  template = "${file("policies/fastq-data-bucket-policy.json")}"
}

resource "aws_s3_bucket_policy" "fastq_data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  bucket = "${aws_s3_bucket.fastq_data.id}"
  policy = "${data.template_file.fastq_data_bucket_policy.rendered}"
}


# S3 bucket for raw sequencing data
resource "aws_s3_bucket" "raw-sequencing-data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  bucket = "${var.workspace_seq_data_bucket_name[terraform.workspace]}"

  versioning {
    enabled = "${terraform.workspace == "prod" ? true : false}"
  }

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
resource "aws_s3_bucket_public_access_block" "raw-sequencing-data" {
  bucket = "${aws_s3_bucket.raw-sequencing-data.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# # S3 bucket for research data
# resource "aws_s3_bucket" "research" {

#   count  = "${terraform.workspace == "dev" ? 1 : 0}"
#   bucket = "${var.workspace_research_bucket_name[terraform.workspace]}"

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }

# # S3 bucket for temp data
# resource "aws_s3_bucket" "temp" {
#   count  = "${terraform.workspace == "dev" ? 1 : 0}"
#   bucket = "${var.workspace_temp_bucket_name[terraform.workspace]}"

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
#   lifecycle_rule {
#     id      = "monthly cleanup"
#     enabled = true

#     expiration {
# 	  days = 30
#     }

#     abort_incomplete_multipart_upload_days = 5
#   }
# }

resource "aws_s3_bucket" "run-data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  bucket = "${var.workspace_run_data_bucket_name[terraform.workspace]}"

  versioning {
    enabled = "${terraform.workspace == "prod" ? true : false}"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "expire_old_version"
    enabled = "${terraform.workspace == "dev" ? false : true}"

    noncurrent_version_expiration {
      days = 90
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload_days = 7
  }

}
resource "aws_s3_bucket_public_access_block" "run-data" {
  bucket = "${aws_s3_bucket.run-data.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket to hold primary data
resource "aws_s3_bucket" "primary_data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
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

  lifecycle_rule {
    id      = "intelligent_tiering"
    enabled = "${terraform.workspace == "dev" ? false : true}"

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }

    noncurrent_version_expiration {
      days = 90
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload_days = 7
  }

  lifecycle_rule {
    id      = "glacier_older_than_60_days_bams"
    enabled = "${terraform.workspace == "dev" ? false : true}"

    tags = {
      "Filetype" = "bam"
      "Archive"  = "true"
    }

    transition {
      days          = 60
      storage_class = "DEEP_ARCHIVE"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "primary_data" {
  bucket = "${aws_s3_bucket.primary_data.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket to hold validation data
resource "aws_s3_bucket" "validation_data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  bucket = "${var.workspace_validation_bucket_name[terraform.workspace]}"
  acl    = "private"

  versioning {
    enabled = "${terraform.workspace == "prod" ? true : false}"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    Name        = "validation"
    Environment = "${terraform.workspace}"
  }

  lifecycle_rule {
    # TODO: data could go straight to INFREQUENT_ACCESS in both dev and prod?
    id      = "intelligent_tiering"
    enabled = "${terraform.workspace == "prod" ? true : false}"

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload_days = 7
  }
}
resource "aws_s3_bucket_public_access_block" "validation_data" {
  bucket = "${aws_s3_bucket.validation_data.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "template_file" "validation_bucket_policy" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  template = "${file("policies/cross_account_bucket_policy.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.validation_data.id}"
    account_id  = "${var.dev_account_id}"
  }
}

resource "aws_s3_bucket_policy" "validation_bucket_policy" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  bucket = "${aws_s3_bucket.validation_data.id}"
  policy = "${data.template_file.validation_bucket_policy.rendered}"
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
  timeout       = 10

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

################################################################################
# Set up a main VPC for resources to use
# It'll have with private and public subnets, internet and NAT gateways, etc

# THIS IS REPLACED WITH Networking STACK
# See https://github.com/umccr/infrastructure/tree/master/terraform/stacks/networking

#module "app_vpc" {
#  source = "git::git@github.com:umccr/gruntworks-io-module-vpc.git//modules/vpc-app?ref=v0.5.2"
#
#  vpc_name   = "vpc-${var.stack_name}-main"
#  aws_region = "ap-southeast-2"
#
#  cidr_block = "10.2.0.0/18"
#
#  num_nat_gateways = 1
#
#  use_custom_nat_eips = true
#  custom_nat_eips     = ["${aws_eip.main_vpc_nat_gateway.id}"]
#
#  custom_tags = {
#    Environment = "${terraform.workspace}"
#    Stack       = "${var.stack_name}"
#  }
#
#  public_subnet_custom_tags = {
#    SubnetType = "public"
#  }
#
#  private_app_subnet_custom_tags = {
#    SubnetType = "private_app"
#  }
#
#  private_persistence_subnet_custom_tags = {
#    SubnetType = "private_persistence"
#  }
#}

#resource "aws_eip" "main_vpc_nat_gateway" {
#  vpc = true
#
#  tags {
#    Environment = "${terraform.workspace}"
#    Stack       = "${var.stack_name}"
#    Name        = "main_vpc_nat_gateway_1_${terraform.workspace}"
#  }
#}

################################################################################
# Dedicated user to generate long lived presigned URLs
# See: https://aws.amazon.com/premiumsupport/knowledge-center/presigned-url-s3-bucket-expiration/

module "presigned_urls" {
  source   = "../../modules/iam_user/secure_user"
  username = "presigned_urls"
  pgp_key  = "keybase:brainstorm"
}

resource "aws_iam_user_policy_attachment" "presigned_user_primary_data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  user       = "${module.presigned_urls.username}"
  policy_arn = "${aws_iam_policy.primary_data_reader.arn}"
}

resource "aws_iam_user_policy_attachment" "presigned_user_fastq_data" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  user       = "${module.presigned_urls.username}"
  policy_arn = "${aws_iam_policy.fastq_data_reader.arn}"
}

data "template_file" "fastq_data_reader" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  template = "${file("policies/primary_data_reader.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.fastq_data.id}"
  }
}

resource "aws_iam_policy" "fastq_data_reader" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  name   = "fastq_data_reader_${terraform.workspace}"
  path   = "/"
  policy = "${data.template_file.fastq_data_reader.rendered}"
}

data "template_file" "primary_data_reader" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  template = "${file("policies/primary_data_reader.json")}"

  vars {
    bucket_name = "${aws_s3_bucket.primary_data.id}"
  }
}

resource "aws_iam_policy" "primary_data_reader" {
  count  = "${terraform.workspace == "prod" ? 1 : 0}"
  name   = "primary_data_reader_${terraform.workspace}"
  path   = "/"
  policy = "${data.template_file.primary_data_reader.rendered}"
}
