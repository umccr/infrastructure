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

resource "aws_iam_role" "pcgr_role" {
  name               = "pcgr_role${var.workspace_name_suffix[terraform.workspace]}"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.pcgr_assume_policy.json}"
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
resource "aws_iam_policy" "ec2_pcgr_policy" {
  path   = "/"
  policy = "${file("${path.module}/policies/ec2.json")}"
}
resource "aws_iam_policy" "sqs_pcgr_policy" {
  path   = "/"
  policy = "${file("${path.module}/policies/sqs.json")}"
}
resource "aws_iam_policy_attachment" "ec2_policy_to_role_attachment" {
  name       = "ec2_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.ec2_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

resource "aws_iam_policy_attachment" "sqs_policy_to_role_attachment" {
  name       = "sqs_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.sqs_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

resource "aws_iam_policy_attachment" "s3_policy_to_role_attachment" {
  name       = "s3_policy_to_role_attachment${var.workspace_name_suffix[terraform.workspace]}"
  policy_arn = "${aws_iam_policy.s3_pcgr_policy.arn}"
  roles      = ["${aws_iam_role.pcgr_role.name}"]
}

# data "aws_ami" "pcgr_ami" {
#   most_recent      = true
#   owners           = [ "620123204273" ]
#   executable_users = [ "self" ]
#   name_regex = "^pcgr-ami*"
#
# }

# resource "aws_spot_instance_request" "pcgr_instance" {
#   spot_price             = "${var.instance_spot_price}"
#   wait_for_fulfillment   = true
#
#   ami                    = "${data.aws_ami.pcgr_ami.id}"
#   instance_type          = "${var.instance_type}"
#   iam_instance_profile   = "${aws_iam_instance_profile.instance_profile.id}"
#   availability_zone      = "ap-southeast-2"
#   subnet_id              = "${aws_subnet.vpc_subnet_a_pcgr.id}"
#   vpc_security_group_ids = ["${aws_security_group.vpc_pcgr.id}"]
#
#   monitoring             = true
#
#   # tags apply to the spot request, NOT the instance!
#   # https://github.com/terraform-providers/terraform-provider-aws/issues/174
#   # https://github.com/hashicorp/terraform/issues/3263#issuecomment-284387578
#   tags {
#     Name = "pcgr${var.workspace_name_suffix[terraform.workspace]}"
#   }
# }

resource "aws_vpc" "vpc_pcgr" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags {
    Name = "vpc_pcgr${var.workspace_name_suffix[terraform.workspace]}"
  }
}

resource "aws_subnet" "vpc_subnet_a_pcgr" {
  vpc_id                  = "${aws_vpc.vpc_pcgr.id}"
  cidr_block              = "172.31.0.0/20"
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

resource "aws_iam_role" "iam_for_lambda" {
  assume_role_policy = "${file("${path.module}/policies/lambda_assume_role.json")}"
}

resource "aws_lambda_function" "pcgr_lambda_trigger" {
  filename         = "lambda_function_triggerPCGR.zip"
  function_name    = "lambda_handler"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = "${base64sha256(file("${path.module}/lambda/lambda_function_triggerPCGR.zip"))}"
  runtime          = "python3.6"

  environment {
    variables = {
      QUEUE_NAME  = "${var.stack}"
      ST2_API_KEY = "${data.vault_generic_secret.pcgr.data["st2-api-key"]}"
      ST2_API_URL = "http://${var.workspace_st2_host[terraform.workspace]}/api"
      ST2_HOST    = "${var.workspace_st2_host[terraform.workspace]}"
    }
  }
}

resource "aws_lambda_function" "pcgr_lambda_done" {
  filename         = "lambda_function_donePCGR.zip"
  function_name    = "lambda_handler"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = "${base64sha256(file("${path.module}/lambda/lambda_function_donePCGR.zip"))}"
  runtime          = "python3.6"

  environment {
    variables = {
      QUEUE_NAME  = "${var.stack}"
      ST2_API_KEY = "${data.vault_generic_secret.pcgr.data["st2-api-key"]}"
      ST2_API_URL = "http://${var.workspace_st2_host[terraform.workspace]}/api"
      ST2_HOST    = "${var.workspace_st2_host[terraform.workspace]}"
    }
  }
}
