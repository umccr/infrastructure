terraform {
  required_version = ">= 1.5.4"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "umccr_demo_admin/terraform.tfstate"
    region = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "5.12.0"
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  common_tags = {
    "Environment": "demo",
    "Stack": "umccr_demo_admin"
  }
}



resource "aws_iam_user" "elsa_presign" {
  name = "elsa_presign"
  path = "/elsa/"
  force_destroy = true
  tags = local.common_tags
}

resource "aws_iam_group" "elsa_presign" {
  name = "elsa_presign_group"
  path = "/elsa/"
}

resource "aws_iam_group_membership" "elsa_presign" {
  name  = "${aws_iam_group.elsa_presign.name}_membership"
  group = aws_iam_group.elsa_presign.name
  users = [
    aws_iam_user.elsa_presign.name
  ]
}

resource "aws_iam_group_policy_attachment" "elsa_presign" {
  group      = aws_iam_group.elsa_presign.name
  policy_arn = aws_iam_policy.elsa_presign.arn
}

data "template_file" "elsa_presign" {
  template = file("policies/elsa_presign_user_policy.json")

  vars = {
    bucket_name = var.elsa_read_bucket_name
  }
}
resource "aws_iam_policy" "elsa_presign" {
  name_prefix = "elsa_presign"
  path        = "/elsa/"
  policy      = data.template_file.elsa_presign.rendered
  tags        = local.common_tags
}
