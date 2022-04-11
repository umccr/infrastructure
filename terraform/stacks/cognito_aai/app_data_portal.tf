# -*- coding: utf-8 -*-
#
# Note: Data Portal App Client
#

locals {
  portal = "data-portal"

  portal_domain = "data.${var.base_domain[terraform.workspace]}"

  portal_alias_domain = {
      prod = "data.umccr.org"
      dev  = ""
  }

  portal_callback_urls = {
    prod = ["https://${local.portal_domain}", "https://${local.portal_alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.portal_domain}"]
  }

  portal_oauth_redirect_url = {
    prod = "https://${local.portal_alias_domain[terraform.workspace]}"
    dev  = "https://${local.portal_domain}"
  }

  portal_param_prefix = "/data_portal/client"
}

# data-portal app client
resource "aws_cognito_user_pool_client" "portal_app_client" {
  name                         = "${local.portal}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.portal_callback_urls[terraform.workspace]
  logout_urls   = local.portal_callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  id_token_validity = 24

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

resource "aws_ssm_parameter" "portal_app_client_id_stage" {
  name  = "${local.portal_param_prefix}/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.portal_app_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "portal_oauth_redirect_in_stage" {
  name  = "${local.portal_param_prefix}/oauth_redirect_in_stage"
  type  = "String"
  value = local.portal_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "portal_oauth_redirect_out_stage" {
  name  = "${local.portal_param_prefix}/oauth_redirect_out_stage"
  type  = "String"
  value = local.portal_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
