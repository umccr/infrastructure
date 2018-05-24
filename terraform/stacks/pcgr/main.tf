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


resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.stack}_instance_profile${var.workspace_name_suffix[terraform.workspace]}"
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
  name               = "pcgr_role${var.workspace_name_suffix[terraform.workspace]}"
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
  path   = "/"
  policy = "${data.template_file.s3_pcgr_policy.rendered}"
}
resource "aws_iam_policy_attachment" "s3_policy_to_role_attachment" {
  name       = "s3_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.s3_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

resource "aws_iam_policy" "ec2_pcgr_policy" {
  path   = "/"
  policy = "${file("${path.module}/policies/ec2.json")}"
}
resource "aws_iam_policy_attachment" "ec2_policy_to_role_attachment" {
  name       = "ec2_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.ec2_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

resource "aws_iam_policy" "sqs_pcgr_policy" {
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
    Name = "vpc_pcgr${var.workspace_name_suffix[terraform.workspace]}"
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
  name        = "sg_pcgr${var.workspace_name_suffix[terraform.workspace]}"
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

# TODO: find a way to attach event trigger to function (perhaps via aws cli command)
module "lambda" {
  source = "github.com/claranet/terraform-aws-lambda"

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
      QUEUE_NAME  = "${var.stack}"
      ST2_API_KEY = "${data.vault_generic_secret.pcgr.data["st2-api-key"]}"
      ST2_API_URL = "http://${var.workspace_st2_host[terraform.workspace]}/api"
      ST2_HOST    = "${var.workspace_st2_host[terraform.workspace]}"
    }
  }
}

module "lambda" {
  source = "github.com/claranet/terraform-aws-lambda"

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
      QUEUE_NAME  = "${var.stack}"
      ST2_API_KEY = "${data.vault_generic_secret.pcgr.data["st2-api-key"]}"
      ST2_API_URL = "http://${var.workspace_st2_host[terraform.workspace]}/api"
      ST2_HOST    = "${var.workspace_st2_host[terraform.workspace]}"
    }
  }
}

data "template_file" "lambda_policy" {
    template = "${file("${path.module}/policies/lambda-policies.json")}"
    vars {
        bucket_name = "${var.workspace_pcgr_bucket_name[terraform.workspace]}"
    }
}
resource "aws_iam_policy" "lambda_policy" {
  path   = "/"
  policy = "${data.template_file.lambda_policy.rendered}"
}
