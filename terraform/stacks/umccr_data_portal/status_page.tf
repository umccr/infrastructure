# -*- coding: utf-8 -*-
#
# Note: data-portal-status-page  app reuse some Portal TF created resources such as Cognito. 
# This streamlines integrate UI login to the same authority.

locals {

  app_name   = "data-portal-status-page"
  sub_domain = "status.data"

  data_portal_status_page_app_domain = "${local.sub_domain}.${var.base_domain[terraform.workspace]}"

  data_portal_status_page_alias_domain = {
    prod = "status.data.umccr.org"
    dev  = ""
  }

  data_portal_status_page_callback_urls = {
    prod = ["https://${local.data_portal_status_page_app_domain}", "https://${local.data_portal_status_page_alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.data_portal_status_page_app_domain}"]
  }

  data_portal_status_page_oauth_redirect_url = {
    prod = "https://${local.data_portal_status_page_alias_domain[terraform.workspace]}"
    dev  = "https://${local.data_portal_status_page_app_domain}"
  }

  ssm_parameter_prefix = "/data_portal_status_page"
}

# data-portal-status-page app client
resource "aws_cognito_user_pool_client" "data_portal_status_page_app_client" {
  name                         = "${local.app_name}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.data_portal_status_page_callback_urls[terraform.workspace]
  logout_urls   = local.data_portal_status_page_callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  id_token_validity = 24

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

resource "aws_ssm_parameter" "data_portal_status_page_app_client_id_stage" {
  name  = "${local.ssm_parameter_prefix}/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.data_portal_status_page_app_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "data_portal_status_page_oauth_redirect_in_stage" {
  name  = "${local.ssm_parameter_prefix}/oauth_redirect_in_stage"
  type  = "String"
  value = local.data_portal_status_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "data_portal_status_page_oauth_redirect_out_stage" {
  name  = "${local.ssm_parameter_prefix}/oauth_redirect_out_stage"
  type  = "String"
  value = local.data_portal_status_page_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
