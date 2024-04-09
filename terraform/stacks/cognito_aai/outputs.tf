output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_identity_pool_id" {
  value = aws_cognito_identity_pool.identity_pool.id
}

output "cognito_oauth_domain" {
  value = aws_cognito_user_pool_domain.user_pool_domain.domain
}

# Construct login URL for the Cognito built-in Hosted UI with Portal App Client
# https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-integration.html#cognito-user-pools-app-integration-view-hosted-ui
output "portal_client_hosted_ui" {
  value = "https://${aws_cognito_user_pool_domain.user_pool_domain.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/authorize?client_id=${aws_cognito_user_pool_client.data2_client.id}&response_type=code&redirect_uri=${local.data2_oauth_redirect_url[terraform.workspace]}"
}
