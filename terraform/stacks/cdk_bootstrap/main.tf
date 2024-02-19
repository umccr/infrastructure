terraform {
  required_version = ">= 1.5.4"

  backend "s3" {
    bucket         = "umccr-terraform-states"   # FIXME still using UMCCR tenancy bucket for storing TF state
    key            = "cdk_bootstrap/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "5.12.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_cloudformation_stack" "CDKToolkit" {
  name = "CDKToolkit"
  capabilities = [
    "CAPABILITY_NAMED_IAM"
  ]

  parameters = {
    CloudFormationExecutionPolicies = "arn:aws:iam::aws:policy/AdministratorAccess"  # TODO perhaps further refinement, see README > Trello card
    FileAssetsBucketKmsKeyId        = "AWS_MANAGED_KEY"
    PublicAccessBlockConfiguration  = false  # See https://github.com/aws/aws-cdk/issues/8724 and https://unimelb.slack.com/archives/C05A22M4B4L/p1693437379860939
    // trust the toolchain account for CDK pipeline deployments
    TrustedAccounts                 = "442639098081"
    UseExamplePermissionsBoundary   = false
  }

  template_body = file("${path.module}/bootstrap-template.yaml")
}
