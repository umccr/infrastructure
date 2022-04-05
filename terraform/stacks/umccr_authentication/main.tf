terraform {
  required_version = ">= 1.1.7"

  backend "s3" {
    bucket = "umccr-terraform-states"
    key    = "umccr_auth/terraform.tfstate"
    region = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      version = "4.4.0"
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "ap-southeast-2"
}

locals {
  # Stack name in under socre
  stack_name_us = "umccr_auth"

  # Stack name in dash
  stack_name_dash = "umccr-auth"

  default_tags = {
    "Stack"       = local.stack_name_us
    "Creator"     = "terraform"
    "Environment" = terraform.workspace
  }

  iam_role_path = "/${local.stack_name_us}/"

}


################################################################################
# Query for Pre-configured SSM Parameter Store
# These are pre-populated outside of terraform i.e. manually using Console or CLI
# TODO: re-name/re-create ssm parameter with prefix "/umccr" instead of "/data_portal"

data "aws_ssm_parameter" "google_oauth_client_id" {
  name  = "/data_portal/${terraform.workspace}/google/oauth_client_id"
}

data "aws_ssm_parameter" "google_oauth_client_secret" {
  name  = "/data_portal/${terraform.workspace}/google/oauth_client_secret"
}

################################################################################
# Cognito

resource "aws_cognito_user_pool" "user_pool" {
  name = "${local.stack_name_dash}-${terraform.workspace}"

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = merge(local.default_tags)
}

# Google identity provider
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

# User pool client (localhost access)
resource "aws_cognito_user_pool_client" "user_pool_client_localhost" {
  name                         = "${local.stack_name_dash}-app-${terraform.workspace}-localhost"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = [var.localhost_url]
  logout_urls   = [var.localhost_url]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  explicit_auth_flows                  = ["ADMIN_NO_SRP_AUTH"]

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

# Assign an explicit domain
resource "aws_cognito_user_pool_domain" "user_pool_client_domain" {
  domain       = "${local.stack_name_dash}-app-${terraform.workspace}"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}


################################################################################
# Save configurations in SSM Parameter Store

# Save these in SSM Parameter Store for frontend client localhost development purpose

resource "aws_ssm_parameter" "cog_user_pool_id" {
  name  = "/${local.stack_name_us}/cog_user_pool_id"
  type  = "String"
  value = aws_cognito_user_pool.user_pool.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "cog_app_client_id_local" {
  name  = "/${local.stack_name_us}/cog_app_client_id_local"
  type  = "String"
  value = aws_cognito_user_pool_client.user_pool_client_localhost.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_domain" {
  name  = "/${local.stack_name_us}/oauth_domain"
  type  = "String"
  value = aws_cognito_user_pool_domain.user_pool_client_domain.domain
  tags  = merge(local.default_tags)
}
