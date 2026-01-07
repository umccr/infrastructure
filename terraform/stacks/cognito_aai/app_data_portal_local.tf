# -*- coding: utf-8 -*-
#
# Note: Data Portal App Localhost Client
#

locals {
  portal              = "data-portal"
  portal_param_prefix = "/data_portal/client"
}

# data-portal app client for local dev (localhost access)
resource "aws_cognito_user_pool_client" "portal_app_client_local" {
  name                         = "${local.portal}-app-${terraform.workspace}-localhost"
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

resource "aws_ssm_parameter" "portal_app_client_id_local" {
  name  = "${local.portal_param_prefix}/cog_app_client_id_local"
  type  = "String"
  value = aws_cognito_user_pool_client.portal_app_client_local.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "portal_oauth_redirect_in_local" {
  name  = "${local.portal_param_prefix}/oauth_redirect_in_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local.callback_urls)[0]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "portal_oauth_redirect_out_local" {
  name  = "${local.portal_param_prefix}/oauth_redirect_out_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local.logout_urls)[0]
  tags  = merge(local.default_tags)
}
