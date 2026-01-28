terraform {
  required_version = ">= 1.5.7"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "cognito_aai/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.21.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  # Retain stack name to data-portal for now as rename will escalate recreation.
  # And this is purely textual to this point. Stack itself is pretty much independent code-wise.
  stack_name_us   = "data_portal"
  stack_name_dash = "data-portal"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
    "Source"      = "https://github.com/umccr/infrastructure/blob/master/terraform/stacks/cognito_aai"
  }

  iam_role_path = "/${local.stack_name_us}/"

  ssm_param_key_client_prefix = "/${local.stack_name_us}/client" # pls note this namespace param has few references
}

data "aws_region" "current" {}

################################################################################
# Query for Pre-configured SSM Parameter Store
# These are pre-populated outside of terraform i.e. manually using Console or CLI

data "aws_ssm_parameter" "google_oauth_client_id" {
  name = "/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_id"
}

data "aws_ssm_parameter" "google_oauth_client_secret" {
  name = "/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_secret"
}

################################################################################
# Cognito User Pool

# Main user pool AAI and OAuth broker
resource "aws_cognito_user_pool" "user_pool" {
  name = "${local.stack_name_dash}-${terraform.workspace}"

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = merge(local.default_tags)
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain       = "${local.stack_name_dash}-app-${terraform.workspace}"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

# Add Google as identity provider
resource "aws_cognito_identity_provider" "identity_provider" {
  user_pool_id  = aws_cognito_user_pool.user_pool.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id                     = data.aws_ssm_parameter.google_oauth_client_id.value
    client_secret                 = data.aws_ssm_parameter.google_oauth_client_secret.value
    authorize_scopes              = "openid profile email"
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = true
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    oidc_issuer                   = "https://accounts.google.com"
    token_request_method          = "POST"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

################################################################################
# Cognito User Group
# Defining group roles within this data-portal cognito user pool


# admin
# 
# The admin role should ideally have full read/write permissions within the data-portal Cognito 
# user pool. The specific actions it can perform depend on the applications/stacks 
# using this role as their principal.
# 
# Use case: OrcaBus Admins
resource "aws_cognito_user_group" "main" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Admin group role within the data-portal cognito user pool"
}

# curators
# 
# Group for curators with inherited actions.
# Curators generally have read permissions and limited actions (e.g. rerun RNAsum).
# Actual implementation is handled at the application level.
resource "aws_cognito_user_group" "curators_cognito_group" {
  name         = "curators"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Group for curators with actions applied to all members"
}

# bioinfo
# 
# Group for bioinformatics members.
# Bioinformatics members generally have the same permissions as curators with additional actions.
# Actual implementation is handled at the application level.
resource "aws_cognito_user_group" "bioinfo_cognito_group" {
  name         = "bioinfo"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  description  = "Group for bioinformatics members"
}


################################################################################
# Save configurations in SSM Parameter Store

resource "aws_ssm_parameter" "cog_user_pool_id" {
  name  = "${local.ssm_param_key_client_prefix}/cog_user_pool_id"
  type  = "String"
  value = aws_cognito_user_pool.user_pool.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_domain" {
  name  = "${local.ssm_param_key_client_prefix}/oauth_domain"
  type  = "String"
  value = aws_cognito_user_pool_domain.user_pool_domain.domain
  tags  = merge(local.default_tags)
}
