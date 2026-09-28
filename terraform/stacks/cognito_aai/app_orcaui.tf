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

  # Origins this app client may return a user to, in the current workspace. Prod is reachable on both
  # the stage domain and the shorter alias, so both are registered.
  orcaui_origins = compact([
    "https://${local.orcaui_domain}",
    local.orcaui_alias_domain[terraform.workspace] == "" ? "" : "https://${local.orcaui_alias_domain[terraform.workspace]}",
  ])

  orcaui_page_callback_urls = [
    for pair in setproduct(local.orcaui_origins, local.portal_app_paths) :
    "${pair[0]}${pair[1]}"
  ]

  orcaui_page_oauth_redirect_url = {
    prod = "https://${local.orcaui_alias_domain["prod"]}"
    dev  = "https://${local.orcaui_domain}"
    stg  = "https://${local.orcaui_domain}"
  }

  app_orcaui_param_prefix = "/cognito/orcaui-app"
}

# orcaui-page app client
resource "aws_cognito_user_pool_client" "orcaui_page_app_client" {
  name                         = "${local.app_namespace}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  # One entry per portal app per origin; see portal_apps.tf for why each path needs its own URL.
  callback_urls = local.orcaui_page_callback_urls
  logout_urls   = local.orcaui_page_callback_urls

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

#------------------------------------------------------------------------------
# Legacy SSM Parameters - DEPRECATED
#------------------------------------------------------------------------------
# Maintained for backward compatibility with existing data-portal consumers.
# Migrate to new parameters under '/cognito/localhost-app/' prefix.

resource "aws_ssm_parameter" "orcaui_page_app_client_id_stage" {
  name  = "/orcaui/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.orcaui_page_app_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "orcaui_page_oauth_redirect_in_stage" {
  name  = "/orcaui/oauth_redirect_in_stage"
  type  = "String"
  value = local.orcaui_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "orcaui_page_oauth_redirect_out_stage" {
  name  = "/orcaui/oauth_redirect_out_stage"
  type  = "String"
  value = local.orcaui_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
#------------------------------------------------------------------------------


resource "aws_ssm_parameter" "orcaui_page_client_id" {
  name  = "${local.app_orcaui_param_prefix}/app-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.orcaui_page_app_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "orcaui_oauth_redirect_in" {
  name  = "${local.app_orcaui_param_prefix}/oauth-redirect-in"
  type  = "String"
  value = local.orcaui_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "orcaui_oauth_redirect_out" {
  name  = "${local.app_orcaui_param_prefix}/oauth-redirect-out"
  type  = "String"
  value = local.orcaui_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
