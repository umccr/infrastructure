# NOTE: AWS profile is hard coded for convenience
terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    bucket         = "agha-terraform-states"
    key            = "agha_incoming/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = "${var.aws_region}"
}

################################################################################
# prepare local variables

locals {
  bucket_arns = "${concat(formatlist("arn:aws:s3:::%s", var.agha_buckets), formatlist("arn:aws:s3:::%s/*", var.agha_buckets))}"
}

################################################################################
# EC2 instance setup to access data in s3://agha-gdr-staging-dev
data "template_file" "userdata" {
  template = "${file("${path.module}/templates/userdata.tpl")}"

  vars {
    BUCKETS       = "${join(" ", var.agha_buckets)}"
    INSTANCE_TAGS = "${jsonencode(var.instance_tags)}"
  }
}

data "aws_security_group" "outbound" {
  name = "outbound-only"
}

# find the lastest Amazon Linux 2 AMI
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
data "aws_ami" "AmazonLinux2" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????.?-x86_64-gp2"]
  }
}

resource "aws_spot_instance_request" "agha_instance" {
  wait_for_fulfillment = true

  ami                  = "${data.aws_ami.AmazonLinux2.image_id}"
  instance_type        = "${var.instance_type}"
  availability_zone    = "${var.availability_zone}"
  iam_instance_profile = "${aws_iam_instance_profile.instance_profile.id}"

  vpc_security_group_ids = [ "${data.aws_security_group.outbound.id}" ]

  user_data = "${data.template_file.userdata.rendered}"
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 500
    delete_on_termination = true
    encrypted             = true
  }
  # tags apply to the spot request, NOT the instance!
  # https://github.com/terraform-providers/terraform-provider-aws/issues/174
  # https://github.com/hashicorp/terraform/issues/3263#issuecomment-284387578
  tags {
    Name = "${var.stack_name}_spot_request_${terraform.workspace}"
  }
}

################################################################################
# EC2 instance profile
resource "aws_iam_instance_profile" "instance_profile" {
  role = "${aws_iam_role.instance_profile.name}"
}

resource "aws_iam_role" "instance_profile" {
  name = "${var.stack_name}_instance_role"
  path = "/${var.stack_name}/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("policies/instance-profile.json")}"

  vars {
    resources = "${jsonencode(local.bucket_arns)}"
  }
}

resource "aws_iam_policy" "instance_profile" {
  path   = "/${var.stack_name}/"
  policy = "${data.template_file.instance_profile.rendered}"
}

resource "aws_iam_role_policy_attachment" "instance_profile" {
  role       = "${aws_iam_role.instance_profile.name}"
  policy_arn = "${aws_iam_policy.instance_profile.arn}"
}

################################################################################

