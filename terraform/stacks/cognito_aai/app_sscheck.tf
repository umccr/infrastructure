# -*- coding: utf-8 -*-
#
# Note: Samplesheet Checker App Client
#

locals {
  sscheck = "sscheck"

  sscheck_domain = "${local.sscheck}.${var.base_domain[terraform.workspace]}"

  sscheck_alias_domain = {
    prod = "sscheck.umccr.org"
    dev  = ""
    stg  = ""
  }

  sscheck_callback_urls = {
    prod = ["https://${local.sscheck_domain}", "https://${local.sscheck_alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.sscheck_domain}"]
    stg  = ["https://${local.sscheck_domain}"]
  }

  sscheck_oauth_redirect_url = {
    prod = "https://${local.sscheck_alias_domain[terraform.workspace]}"
    dev  = "https://${local.sscheck_domain}"
    stg  = "https://${local.sscheck_domain}"
  }

  sscheck_param_prefix = "/${local.sscheck}/client"
}

# sscheck app client
resource "aws_cognito_user_pool_client" "sscheck_app_client" {
  name                         = "${local.sscheck}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.sscheck_callback_urls[terraform.workspace]
  logout_urls   = local.sscheck_callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  id_token_validity = 24

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

resource "aws_ssm_parameter" "sscheck_app_client_id_stage" {
  name  = "${local.sscheck_param_prefix}/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.sscheck_app_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sscheck_oauth_redirect_in_stage" {
  name  = "${local.sscheck_param_prefix}/oauth_redirect_in_stage"
  type  = "String"
  value = local.sscheck_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "sscheck_oauth_redirect_out_stage" {
  name  = "${local.sscheck_param_prefix}/oauth_redirect_out_stage"
  type  = "String"
  value = local.sscheck_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
