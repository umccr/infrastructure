# -*- coding: utf-8 -*-
#
# Note: orcaui Page - App Client
#

locals {
  app_namespace = "orcaui"

  orcaui_domain = "portal.${var.base_domain[terraform.workspace]}"

  orcaui_alias_domain = {
    prod = "portal.umccr.org"
    dev  = ""
    stg  = ""
  }

  orcaui_page_callback_urls = {
    prod = ["https://${local.orcaui_domain}", "https://${local.orcaui_alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.orcaui_domain}"]
    stg  = ["https://${local.orcaui_domain}"]
  }

  orcaui_page_oauth_redirect_url = {
    prod = "https://${local.orcaui_alias_domain[terraform.workspace]}"
    dev  = "https://${local.orcaui_domain}"
    stg  = "https://${local.orcaui_domain}"
  }

  orcaui_page_param_prefix = "/orcaui"
}

# orcaui-page app client
resource "aws_cognito_user_pool_client" "orcaui_page_app_client" {
  name                         = "${local.app_namespace}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.orcaui_page_callback_urls[terraform.workspace]
  logout_urls   = local.orcaui_page_callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]


  refresh_token_validity = 30
  access_token_validity  = 60
  id_token_validity      = 1

  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "days"
  }

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
