output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_oauth_domain" {
  value = aws_cognito_user_pool_domain.user_pool_domain.domain
}
