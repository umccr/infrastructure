terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "primary_data_worker/terraform.tfstate"
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
    "Environment", "${terraform.workspace}",
    "Stack", "${var.stack_name}"
  )}"
}

################################################################################
# Worker instance

data "aws_ami" "aws_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn-ami-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_security_groups" "test" {
  filter {
    name   = "group-name"
    values = ["main-vpc-sg-outbound"]
  }
}

data "template_file" "userdata" {
  template = "${file("${path.module}/templates/userdata.tpl")}"

  vars {
    BUCKETS  = "${join(" ", var.workspace_buckets[terraform.workspace])}"
  }
}

resource "aws_instance" "worker_instance" {
  ami                  = "${data.aws_ami.aws_linux_2.id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${var.instance_profile_name}"

  user_data = "${data.template_file.userdata.rendered}"

  security_groups = ["${data.aws_security_groups.test.ids}"]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "${var.instance_vol_size}"
    delete_on_termination = true
  }

  tags = "${merge(
    local.common_tags,
    map(
      "Name", "${var.stack_name}_instance"
    )
  )}"

}

