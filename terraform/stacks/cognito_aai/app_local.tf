# -*- coding: utf-8 -*-
#
# Cognito app client for localhost development
#
# Enables local development environments to authenticate via OAuth flow

locals {
  app_local_namespace              = "localhost"
  app_local_ssm_prefix = "/cognito/localhost-app"
}

# Localhost app client for local development
resource "aws_cognito_user_pool_client" "portal_app_client_local" {
  name                         = "${local.app_local_namespace}-cognito-client"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = [var.localhost_url]
  logout_urls   = [var.localhost_url]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  explicit_auth_flows                  = ["ADMIN_NO_SRP_AUTH"]

  depends_on = [aws_cognito_identity_provider.identity_provider]
}

#------------------------------------------------------------------------------
# Legacy SSM Parameters - DEPRECATED
#------------------------------------------------------------------------------
# Maintained for backward compatibility with existing data-portal consumers.
# Migrate to new parameters under '/cognito/localhost-app/' prefix.

resource "aws_ssm_parameter" "portal_app_client_id_local" {
  name  = "/data_portal/client/cog_app_client_id_local"
  type  = "String"
  value = aws_cognito_user_pool_client.portal_app_client_local.id
  tags  = merge(
    local.default_tags,
    {
      Status      = "deprecated"
      Description = "use ${local.app_local_ssm_prefix}/app-client-id instead"
    }
  )
}

resource "aws_ssm_parameter" "portal_oauth_redirect_in_local" {
  name  = "/data_portal/client/oauth_redirect_in_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local.callback_urls)[0]
  tags  = merge(
    local.default_tags,
    {
      Status      = "deprecated"
      Description = "use ${local.app_local_ssm_prefix}/oauth-redirect-in instead"
    }
  )
}

resource "aws_ssm_parameter" "portal_oauth_redirect_out_local" {
  name  = "/data_portal/client/oauth_redirect_out_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local.logout_urls)[0]
  tags  = merge(
    local.default_tags,
    {
      Status      = "deprecated"
      Description = "use ${local.app_local_ssm_prefix}/oauth-redirect-out instead"
    }
  )
}

#------------------------------------------------------------------------------


resource "aws_ssm_parameter" "localhost_app_client_id" {
  name  = "${local.app_local_ssm_prefix}/app-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.portal_app_client_local.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "localhost_oauth_redirect_in" {
  name  = "${local.app_local_ssm_prefix}/oauth-redirect-in"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local.callback_urls)[0]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "localhost_oauth_redirect_out" {
  name  = "${local.app_local_ssm_prefix}/oauth-redirect-out"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local.logout_urls)[0]
  tags  = merge(local.default_tags)
}
