terraform {
  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "pcgr/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

provider "vault" {
  # Vault server address and access token are retrieved from env variables (VAULT_ADDR and VAULT_TOKEN)
}

data "vault_generic_secret" "pcgr" {
  path = "kv/pcgr"
}


# setup PCGR instance profile with relevant policies
resource "aws_iam_instance_profile" "instance_profile" {
  name = "pcgr_instance_profile${var.workspace_name_suffix[terraform.workspace]}"
  role = "${aws_iam_role.pcgr_role.name}"
}

data "aws_iam_policy_document" "pcgr_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "pcgr_role" {
  name               = "pcgr_instance_role${var.workspace_name_suffix[terraform.workspace]}"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.pcgr_assume_policy.json}"
}

data "template_file" "s3_pcgr_policy" {
    template = "${file("${path.module}/policies/s3_bucket_policy.json")}"
    vars {
        bucket_name = "${var.workspace_pcgr_bucket_name[terraform.workspace]}"
    }
}
resource "aws_iam_policy" "s3_pcgr_policy" {
  name   = "pcgr_instance_s3${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${data.template_file.s3_pcgr_policy.rendered}"
}
resource "aws_iam_policy_attachment" "s3_policy_to_role_attachment" {
  name       = "s3_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.s3_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

resource "aws_iam_policy" "ec2_pcgr_policy" {
  name   = "pcgr_instance_ec2${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${file("${path.module}/policies/ec2.json")}"
}
resource "aws_iam_policy_attachment" "ec2_policy_to_role_attachment" {
  name       = "ec2_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.ec2_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

resource "aws_iam_policy" "sqs_pcgr_policy" {
  name   = "pcgr_instance_sqs${var.workspace_name_suffix[terraform.workspace]}"
  path   = "/"
  policy = "${file("${path.module}/policies/sqs.json")}"
}
resource "aws_iam_policy_attachment" "sqs_policy_to_role_attachment" {
  name       = "sqs_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.sqs_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

resource "aws_vpc" "vpc_pcgr" {
  cidr_block           = "172.32.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags {
    Name = "pcgr_instance_vpc${var.workspace_name_suffix[terraform.workspace]}"
  }
}
resource "aws_subnet" "vpc_subnet_a_pcgr" {
  vpc_id                  = "${aws_vpc.vpc_pcgr.id}"
  cidr_block              = "172.32.0.0/20"
  map_public_ip_on_launch = true
  availability_zone       = "${var.availability_zone}"

  tags {
    Name = "vpc_subnet_a_pcgr${var.workspace_name_suffix[terraform.workspace]}"
  }
}
resource "aws_security_group" "vpc_pcgr" {
  name        = "pcgr_instance_sg${var.workspace_name_suffix[terraform.workspace]}"
  description = "Security group for pcgr VPC"
  vpc_id      = "${aws_vpc.vpc_pcgr.id}"

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


# add lambdas
module "lambda_pcgr_trigger" {
  source = "git::https://github.com/claranet/terraform-aws-lambda"

  function_name = "pcgr_trigger_lambda"
  description   = "Lambda function to trigger PCGR data arrival"
  handler       = "lambda_function_triggerPCGR.lambda_handler"
  runtime       = "python3.6"
  timeout       = 300

  source_path = "${path.module}/lambda/lambda_function_triggerPCGR.py"

  attach_policy = true
  policy        = "${aws_iam_policy.lambda_policy.policy}"

  environment {
    variables {
      QUEUE_NAME  = "${var.pcgr_sqs_queue}"
      ST2_API_KEY = "${data.vault_generic_secret.pcgr.data["st2-api-key"]}"
      ST2_API_URL = "http://${var.workspace_st2_host[terraform.workspace]}/api"
      ST2_HOST    = "${var.workspace_st2_host[terraform.workspace]}"
    }
  }
}
resource "aws_lambda_permission" "allow_s3_for_pcgr_trigger" {
  statement_id   = "AllowExecutionFromS3"
  action         = "lambda:InvokeFunction"
  function_name  = "${module.lambda_pcgr_trigger.function_name}"
  principal      = "s3.amazonaws.com"
  source_account = "${var.workspace_aws_account_number[terraform.workspace]}"
  source_arn     = "arn:aws:s3:::${var.workspace_pcgr_bucket_name[terraform.workspace]}"
}

module "lambda_pcgr_done" {
  source = "git::https://github.com/claranet/terraform-aws-lambda"

  function_name = "pcgr_done_lambda"
  description   = "Lambda function to trigger PCGR done"
  handler       = "lambda_function_donePCGR.lambda_handler"
  runtime       = "python3.6"
  timeout       = 300

  source_path = "${path.module}/lambda/lambda_function_donePCGR.py"

  attach_policy = true
  policy        = "${aws_iam_policy.lambda_policy.policy}"

  environment {
    variables {
      QUEUE_NAME  = "${var.pcgr_sqs_queue}"
      ST2_API_KEY = "${data.vault_generic_secret.pcgr.data["st2-api-key"]}"
      ST2_API_URL = "http://${var.workspace_st2_host[terraform.workspace]}/api"
      ST2_HOST    = "${var.workspace_st2_host[terraform.workspace]}"
    }
  }
}
resource "aws_lambda_permission" "allow_s3_for_pcgr_done" {
  statement_id   = "AllowExecutionFromS3"
  action         = "lambda:InvokeFunction"
  function_name  = "${module.lambda_pcgr_done.function_name}"
  principal      = "s3.amazonaws.com"
  source_account = "${var.workspace_aws_account_number[terraform.workspace]}"
  source_arn     = "arn:aws:s3:::${var.workspace_pcgr_bucket_name[terraform.workspace]}"
}

# notifications for the same bucket need to go in the same
# aws_s3_bucket_notification resource, otherwise they will overwrite each other
resource "aws_s3_bucket_notification" "pcgr_notifications" {
  bucket = "${var.workspace_pcgr_bucket_name[terraform.workspace]}"

  lambda_function {
    lambda_function_arn = "${module.lambda_pcgr_trigger.function_arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = "-germline.tar.gz"
  }
  lambda_function {
    lambda_function_arn = "${module.lambda_pcgr_trigger.function_arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = "-somatic.tar.gz"
  }
  lambda_function {
    lambda_function_arn = "${module.lambda_pcgr_trigger.function_arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = "-normal.tar.gz"
  }
  lambda_function {
    lambda_function_arn = "${module.lambda_pcgr_done.function_arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = "-output.tar.gz"
  }
}

data "template_file" "lambda_policy" {
    template = "${file("${path.module}/policies/lambda-policies.json")}"
    vars {
        bucket_name = "${var.workspace_pcgr_bucket_name[terraform.workspace]}"
    }
}
resource "aws_iam_policy" "lambda_policy" {
  name   = "pcgr_lambda_policy"
  path   = "/"
  policy = "${data.template_file.lambda_policy.rendered}"
}
