output "main_region" {
    value = "${data.aws_region.current.name}"
}

output "api_domain" {
    value = "${local.api_domain}"
}

output "cognito_user_pool_id" {
    value = "${aws_cognito_user_pool.user_pool.id}"
}

output "cognito_app_client_id_localhost" {
    value = "${aws_cognito_user_pool_client.user_pool_client_localhost.id}"
}

output "cognito_app_client_id_stage" {
    value = "${aws_cognito_user_pool_client.user_pool_client.id}"
}

output "cognito_identity_pool_id" {
    value = "${aws_cognito_identity_pool.identity_pool.id}"
}

output "cognito_oauth_domain" {
    value = "${aws_cognito_user_pool_domain.user_pool_client_domain.domain}"
}

output "cognito_oauth_scope" {
    value = ["${aws_cognito_user_pool_client.user_pool_client.allowed_oauth_scopes}"]
}

output "cognito_oauth_redirect_signin_localhost" {
    value = "${aws_cognito_user_pool_client.user_pool_client_localhost.callback_urls[0]}"
}

output "cognito_oauth_redirect_signin" {
    value = "${aws_cognito_user_pool_client.user_pool_client.callback_urls[0]}"
}

output "cognito_oauth_redirect_signout_localhost" {
    value = "${aws_cognito_user_pool_client.user_pool_client_localhost.logout_urls[0]}"
}

output "cognito_oauth_redirect_signout" {
    value = "${aws_cognito_user_pool_client.user_pool_client.logout_urls[0]}"
}

output "cognito_oauth_response_type" {
  value = "${aws_cognito_user_pool_client.user_pool_client.allowed_oauth_flows[0]}"
}
