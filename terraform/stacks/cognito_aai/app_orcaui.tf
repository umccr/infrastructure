# -*- coding: utf-8 -*-
#
# Note: orcaui Page - App Client
#

locals {
  orcaui_page   = "orcaui"

  orcaui_page_domain = "orcaui.${var.base_domain[terraform.workspace]}"

  orcaui_page_alias_domain = {
    prod = "orcaui.umccr.org"
    dev  = ""
    stg  = ""
  }

  orcaui_page_callback_urls = {
    prod = ["https://${local.orcaui_page_domain}", "https://${local.orcaui_page_alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.orcaui_page_domain}"]
    stg  = ["https://${local.orcaui_page_domain}"]
  }

  orcaui_page_oauth_redirect_url = {
    prod = "https://${local.orcaui_page_alias_domain[terraform.workspace]}"
    dev  = "https://${local.orcaui_page_domain}"
    stg  = "https://${local.orcaui_page_domain}"
  }

  orcaui_page_param_prefix = "/orcaui"
}

# orcaui-page app client
resource "aws_cognito_user_pool_client" "orcaui_page_app_client" {
  name                         = "${local.orcaui_page}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.orcaui_page_callback_urls[terraform.workspace]
  logout_urls   = local.orcaui_page_callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  id_token_validity = 24

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

resource "aws_ssm_parameter" "orcaui_page_app_client_id_stage" {
  name  = "${local.orcaui_page_param_prefix}/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.orcaui_page_app_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "orcaui_page_oauth_redirect_in_stage" {
  name  = "${local.orcaui_page_param_prefix}/oauth_redirect_in_stage"
  type  = "String"
  value = local.orcaui_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "orcaui_page_oauth_redirect_out_stage" {
  name  = "${local.orcaui_page_param_prefix}/oauth_redirect_out_stage"
  type  = "String"
  value = local.orcaui_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
