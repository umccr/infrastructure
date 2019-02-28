terraform {
  required_version = "~> 0.11.6"

  backend "s3" {
    # AWS access credentials are retrieved from env variables
    bucket         = "umccr-terraform-states"
    key            = "serverless_beacon/terraform.tfstate"
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

################################################################################

module "serverless_beacon" {
  # there are issues with getting the module from the registry => fall back to GitHub
  # source  = "aehrc/serverless-beacon/aws"
  # version = "1.1.0"
  source = "git@github.com:aehrc/terraform-aws-serverless-beacon.git"

  beacon-id         = "org.umccr.beacon"
  beacon-name       = "UMCCR beacon"
  organisation-id   = "org.umccr"
  organisation-name = "UMCCR"
}
