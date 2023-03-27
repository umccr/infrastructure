terraform {
  required_version = ">= 1.4.2"

  backend "s3" {
    bucket         = "umccr-terraform-states"
    key            = "cognito_aai/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.59.0"
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
  }

  iam_role_path = "/${local.stack_name_us}/"

  ssm_param_key_client_prefix = "/${local.stack_name_us}/client"  # pls note this namespace param has few references
}

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
# Cognito Identity Pool

# Main identity pool to assume role with web identity for accessing AWS resources
resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = "Data Portal ${terraform.workspace}"
  allow_unauthenticated_identities = false

  # Register your UMCCR client below
  # This could be Web SPA (Single Page Application), Mobile or Desktop app client
  # For which AWS resources are allowed to authenticated user, see policy docs

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.portal_app_client.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  # FIXME: Data Portal App Client for data2 -- this shall be replaced with above, one day.
  #  See `app_data_portal_data2.tf`
  #  See https://github.com/umccr/infrastructure/issues/272
  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.data2_client.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.portal_app_client_local.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.sscheck_app_client.id
    provider_name           = aws_cognito_user_pool.user_pool.endpoint
    server_side_token_check = false
  }

  tags = merge(local.default_tags)
}

resource "aws_iam_role" "role_authenticated" {
  name = "${local.stack_name_us}_identity_pool_authenticated"
  path = local.iam_role_path

  assume_role_policy = templatefile("policies/iam_role_authenticated_assume_role_policy.json", {
    identity_pool_id = aws_cognito_identity_pool.identity_pool.id
  })

  tags = merge(local.default_tags)
}

resource "aws_iam_role_policy" "role_policy_authenticated" {
  name = "${local.stack_name_us}_authenticated_policy"
  role = aws_iam_role.role_authenticated.id

  policy = templatefile("policies/iam_role_authenticated_policy.json", {})
}

resource "aws_cognito_identity_pool_roles_attachment" "identity_pool_role_attach" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id

  roles = {
    "authenticated" = aws_iam_role.role_authenticated.arn
  }
}

################################################################################
# Save configurations in SSM Parameter Store

resource "aws_ssm_parameter" "cog_user_pool_id" {
  name  = "${local.ssm_param_key_client_prefix}/cog_user_pool_id"
  type  = "String"
  value = aws_cognito_user_pool.user_pool.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "cog_identity_pool_id" {
  name  = "${local.ssm_param_key_client_prefix}/cog_identity_pool_id"
  type  = "String"
  value = aws_cognito_identity_pool.identity_pool.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "oauth_domain" {
  name  = "${local.ssm_param_key_client_prefix}/oauth_domain"
  type  = "String"
  value = aws_cognito_user_pool_domain.user_pool_domain.domain
  tags  = merge(local.default_tags)
}
