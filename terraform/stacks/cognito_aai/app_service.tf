# -*- coding: utf-8 -*-
#
# Cognito app client for service-to-service authentication and token generation
#
# Used by OrcaBus token service stack for JWT token generation

locals {
  app_service_namespace = "service"
  app_service_ssm_prefix = "/cognito/service-app"
}

# data-portal app client
resource "aws_cognito_user_pool_client" "data2_client" {
  name         = "${local.app_service_namespace}-cognito-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  supported_identity_providers = ["Google", "COGNITO"]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  explicit_auth_flows = [
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Read this dev.to article. Especially, pay attention to the article's comment discussion about
  # JWT self-contained stateless nature vs token revocation list tracking.
  # https://dev.to/aymanepraxe/mastering-jwt-security-2kgn
  # https://docs.aws.amazon.com/cognito/latest/developerguide/token-revocation.html
  enable_token_revocation = true

  # https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-managing-errors.html
  # https://repost.aws/knowledge-center/cognito-prevent-user-existence-errors
  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 60   # minutes (cognito default)
  id_token_validity      = 1440 # minutes (we bump this to max allow value)
  refresh_token_validity = 30   # 30 days (cognito default)

  # NOTE:
  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_TokenValidityUnitsType.html
  # Though, it says `hours` is avail in the API doc^^ but the actual allow unit type inside the Cognito Console
  # are `minutes` and `days` only for some reason.
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

# For backward compatibility, maintain the legacy SSM parameter for existing consumers.
# The platform-cdk-constructs package (api-gateway config) currently references this path.
# Once all dependent stacks migrate to the new parameter path, this legacy parameter can be removed.
# Migration tracking: https://github.com/OrcaBus/platform-cdk-constructs/blob/3f15cd1648bd5b6672917b260e193a8069365ee3/packages/api-gateway/config.ts#L43
resource "aws_ssm_parameter" "data2_client_id_stage" {
  name  = "/data_portal/client/data2/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.data2_client.id
  tags  = merge(
    local.default_tags,
    {
      Status      = "deprecated"
      Description = "use ${local.app_service_ssm_prefix}/app-client-id instead"
    }
  )
}

resource "aws_ssm_parameter" "service_app_client_id" {
  name  = "${local.app_service_ssm_prefix}/app-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.data2_client.id
  tags  = merge(local.default_tags)
}

