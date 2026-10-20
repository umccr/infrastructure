# -*- coding: utf-8 -*-
#
# Note: docs.umccr.org - App Client
#

locals {
  app_docs_namespace = "docs"

  # docs.umccr.org runs in dev and prod only. In any other workspace of this shared stack, such as stg, this file
  # creates nothing.
  docs_enabled = contains(["dev", "prod"], terraform.workspace)

  docs_domain = "docs.${var.base_domain[terraform.workspace]}"

  docs_alias_domain = lookup({
    prod = "docs.umccr.org"
    dev  = ""
  }, terraform.workspace, "")

  ###
  # docs.umccr.org signs readers in the same way as the portal apps: Amplify in the browser, the Cognito hosted UI
  # and Google. The sign-in page is served at /_auth/ on each docs hostname and sends Cognito back to that exact URL
  # after both sign-in and sign-out, so it is the only callback and logout URL this client needs.
  #
  # Cognito matches redirect_uri exactly, trailing slash included (see portal_apps.tf).
  #
  # The hostnames mirror `DOCS_DOMAIN_NAMES` in infrastructure/config.ts of umccr/docs-platform, which owns the docs
  # CloudFront distribution. Keep the two in step.
  #
  # ORDERING: apply a workspace BEFORE its stage serves /_auth/, or sign-in is rejected with `redirect_mismatch`.
  #
  # Tokens issued to this client must stay unusable against OrcaBus APIs: never add this client ID to the API
  # authorizer client list in OrcaBus/platform-cdk-constructs (packages/api-gateway/config.ts).
  ###
  docs_origins = compact([
    "https://${local.docs_domain}",
    local.docs_alias_domain == "" ? "" : "https://${local.docs_alias_domain}",
  ])

  docs_app_urls = [for origin in local.docs_origins : "${origin}/_auth/"]

  app_docs_ssm_prefix = "/cognito/docs-app"
}

# docs-app app client
resource "aws_cognito_user_pool_client" "docs_app_client" {
  count = local.docs_enabled ? 1 : 0

  name                         = "${local.app_docs_namespace}-app-${terraform.workspace}"
  user_pool_id                 = aws_cognito_user_pool.user_pool.id
  supported_identity_providers = ["Google"]

  callback_urls = local.docs_app_urls
  logout_urls   = local.docs_app_urls

  # Public client: Amplify runs the authorization code flow with PKCE in the browser, as the portal apps do.
  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  # No aws.cognito.signin.user.admin: the docs sign-in page only reads the ID token.
  allowed_oauth_scopes = ["email", "openid", "profile"]

  # Hosted UI sign-in needs no other flow; Amplify renews tokens with REFRESH_TOKEN_AUTH.
  explicit_auth_flows = ["ALLOW_REFRESH_TOKEN_AUTH"]

  # Amplify's signOut() revokes the refresh token.
  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"

  refresh_token_validity = 30
  access_token_validity  = 60
  id_token_validity      = 60

  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

# Read at deploy time by the docs hosting stack (umccr/docs-platform), for the sign-in page, and by OrcaSonar
# (umccr/orcasonar), whose chat API accepts this client's ID tokens.
resource "aws_ssm_parameter" "docs_app_client_id" {
  count = local.docs_enabled ? 1 : 0

  name  = "${local.app_docs_ssm_prefix}/app-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.docs_app_client[0].id
  tags  = merge(local.default_tags)
}

# Both existed before `count`: these keep dev's and prod's in their state. Without them, Terraform would replace the
# client, and a new client ID signs every docs reader out and breaks OrcaSonar's authorizer until it is redeployed.
moved {
  from = aws_cognito_user_pool_client.docs_app_client
  to   = aws_cognito_user_pool_client.docs_app_client[0]
}

moved {
  from = aws_ssm_parameter.docs_app_client_id
  to   = aws_ssm_parameter.docs_app_client_id[0]
}
