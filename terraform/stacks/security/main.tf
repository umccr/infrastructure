terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "security/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  version = "~> 2.64"
  region  = "ap-southeast-2"
}

data "aws_caller_identity" "current" {}

################################################################################

# Set up AWS Support Access role to comply with CIS 1.20
# https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-cis-controls.html#securityhub-cis-controls-1.20
data "aws_iam_policy_document" "account_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "aws_support_access" {
  name               = "aws_support_access"
  path               = "/${var.stack_name}/"
  assume_role_policy = data.aws_iam_policy_document.account_assume_role_policy.json

  tags = {
    Environment = terraform.workspace
    Stack       = var.stack_name
    Creator     = "terraform"
  }

}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.aws_support_access.name
  policy_arn = var.aws_support_access_policy_arn
}
