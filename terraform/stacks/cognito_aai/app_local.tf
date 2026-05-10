# -*- coding: utf-8 -*-
#
# Cognito app client for localhost development
#
# Enables local development environments to authenticate via OAuth flow

locals {
  ###
  # This configuration controls whether we want to allow localhost dev against remote Cognito environment
  #
  # NOTE:
  # In typical development scenario, allowing localhost dev against STG/PROD remote Cognito environment should be
  # _temporary_ by nature. This would ease with developer needing to _debug_ towards a environment-specific Cognito
  # setup issue. As such debug session should not be last forever.
  #
  # Cognito infra team should provision these resources per developer request basis.
  # A balancing act (team work) between infra and app teams.
  #
  # ~victor
  ###
  allow_cognito_app_local_map = {
    default = false
    dev     = true
    stg     = false
    prod    = false
  }
  # Index into the map using the current workspace name
  allow_cognito_app_local_per_ws = lookup(local.allow_cognito_app_local_map, terraform.workspace, local.allow_cognito_app_local_map["default"])

  app_local_namespace  = "localhost"
  app_local_ssm_prefix = "/cognito/localhost-app"
}

# Localhost app client for local development
resource "aws_cognito_user_pool_client" "portal_app_client_local" {
  count = local.allow_cognito_app_local_per_ws ? 1 : 0

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
  count = local.allow_cognito_app_local_per_ws ? 1 : 0

  name  = "/data_portal/client/cog_app_client_id_local"
  type  = "String"
  value = aws_cognito_user_pool_client.portal_app_client_local[count.index].id
  tags  = merge(
    local.default_tags,
    {
      Status      = "deprecated"
      Description = "use ${local.app_local_ssm_prefix}/app-client-id instead"
    }
  )
}

resource "aws_ssm_parameter" "portal_oauth_redirect_in_local" {
  count = local.allow_cognito_app_local_per_ws ? 1 : 0

  name  = "/data_portal/client/oauth_redirect_in_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local[count.index].callback_urls)[0]
  tags  = merge(
    local.default_tags,
    {
      Status      = "deprecated"
      Description = "use ${local.app_local_ssm_prefix}/oauth-redirect-in instead"
    }
  )
}

resource "aws_ssm_parameter" "portal_oauth_redirect_out_local" {
  count = local.allow_cognito_app_local_per_ws ? 1 : 0

  name  = "/data_portal/client/oauth_redirect_out_local"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local[count.index].logout_urls)[0]
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
  count = local.allow_cognito_app_local_per_ws ? 1 : 0

  name  = "${local.app_local_ssm_prefix}/app-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.portal_app_client_local[count.index].id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "localhost_oauth_redirect_in" {
  count = local.allow_cognito_app_local_per_ws ? 1 : 0

  name  = "${local.app_local_ssm_prefix}/oauth-redirect-in"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local[count.index].callback_urls)[0]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "localhost_oauth_redirect_out" {
  count = local.allow_cognito_app_local_per_ws ? 1 : 0

  name  = "${local.app_local_ssm_prefix}/oauth-redirect-out"
  type  = "String"
  value = sort(aws_cognito_user_pool_client.portal_app_client_local[count.index].logout_urls)[0]
  tags  = merge(local.default_tags)
}
