terraform {
  required_version = ">= 1.5.4"

  backend "s3" {
    bucket         = "umccr-terraform-states"
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
    CloudFormationExecutionPolicies = "arn:aws:iam::aws:policy/AdministratorAccess"
    FileAssetsBucketKmsKeyId        = "AWS_MANAGED_KEY"
    PublicAccessBlockConfiguration  = true
    // trust the umccr-build account for CDK pipeline deployments
    TrustedAccounts                 = "843407916570"
    UseExamplePermissionsBoundary   = false
  }

  template_body = file("${path.module}/bootstrap-template.yaml")
}
