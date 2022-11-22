# -*- coding: utf-8 -*-
#
# FIXME: Data Portal App Client for data2
#  currently using `portal.umccr.org` `portal.prod.umccr.org`
#  This is meant to be replaced with `data.umccr.org` `data.prod.umccr.org` at some point. May be around Q2 '23.
#  See https://github.com/umccr/infrastructure/issues/272
#  See also `data2.tf` from `umccr_data_portal` main TF stack.
#  See https://umccr.slack.com/archives/CP356DDCH/p1666922554239469?thread_ts=1666786848.939379&cid=CP356DDCH
#

locals {
  data2        = "portal"
  data2_domain = "${local.data2}.${var.base_domain[terraform.workspace]}"

  data2_alias_domain = {
    prod = "portal.umccr.org"
    dev  = ""
    stg  = ""
  }

  data2_callback_urls = {
    prod = ["https://${local.data2_domain}", "https://${local.data2_alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.data2_domain}"]
    stg  = ["https://${local.data2_domain}"]
  }

  data2_oauth_redirect_url = {
    prod = "https://${local.data2_alias_domain[terraform.workspace]}"
    dev  = "https://${local.data2_domain}"
    stg  = "https://${local.data2_domain}"
  }

  data2_param_prefix = "/data_portal/client/data2"
}

# data-portal app client
resource "aws_cognito_user_pool_client" "data2_client" {
  name                         = "${local.portal}-app2-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.data2_callback_urls[terraform.workspace]
  logout_urls   = local.data2_callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  id_token_validity = 24

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

resource "aws_ssm_parameter" "data2_client_id_stage" {
  name  = "${local.data2_param_prefix}/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.data2_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "data2_oauth_redirect_in_stage" {
  name  = "${local.data2_param_prefix}/oauth_redirect_in_stage"
  type  = "String"
  value = local.data2_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "data2_oauth_redirect_out_stage" {
  name  = "${local.data2_param_prefix}/oauth_redirect_out_stage"
  type  = "String"
  value = local.data2_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
