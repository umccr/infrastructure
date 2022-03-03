output "main_region" {
  value = data.aws_region.current.name
}

output "api_domain" {
  value = local.api_domain
}

output "cognito_app_client_id_stage" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}

output "cognito_oauth_scope" {
  value = [aws_cognito_user_pool_client.user_pool_client.allowed_oauth_scopes]
}

output "cognito_oauth_response_type" {
  value = [aws_cognito_user_pool_client.user_pool_client.allowed_oauth_flows]
}
