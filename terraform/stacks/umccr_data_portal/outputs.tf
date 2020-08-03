output "main_region" {
  value = data.aws_region.current.name
}

output "api_domain" {
  value = local.api_domain
}

output "cognito_user_pool_id" {
  value = aws_ssm_parameter.cog_user_pool_id.value
}

output "cognito_app_client_id_localhost" {
  value = aws_ssm_parameter.cog_app_client_id_local.value
}

output "cognito_app_client_id_stage" {
  value = aws_cognito_user_pool_client.user_pool_client.id
}

output "cognito_identity_pool_id" {
  value = aws_ssm_parameter.cog_identity_pool_id.value
}

output "cognito_oauth_domain" {
  value = aws_ssm_parameter.oauth_domain.value
}

output "cognito_oauth_redirect_signin_localhost" {
  value = aws_ssm_parameter.oauth_redirect_in_local.value
}

output "cognito_oauth_redirect_signout_localhost" {
  value = aws_ssm_parameter.oauth_redirect_out_local.value
}

output "cognito_oauth_redirect_signin" {
  value = aws_ssm_parameter.oauth_redirect_in_stage.value
}

output "cognito_oauth_redirect_signout" {
  value = aws_ssm_parameter.oauth_redirect_out_stage.value
}

output "cognito_oauth_scope" {
  value = [aws_cognito_user_pool_client.user_pool_client.allowed_oauth_scopes]
}

output "cognito_oauth_response_type" {
  value = [aws_cognito_user_pool_client.user_pool_client.allowed_oauth_flows]
}

output "LAMBDA_IAM_ROLE_ARN" {
  value = aws_ssm_parameter.lambda_iam_role_arn.value
}

output "LAMBDA_SUBNET_IDS" {
  value = aws_ssm_parameter.lambda_subnet_ids.value
}

output "LAMBDA_SECURITY_GROUP_IDS" {
  value = aws_ssm_parameter.lambda_security_group_ids.value
}

output "SSM_KEY_NAME_FULL_DB_URL" {
  value = aws_ssm_parameter.ssm_key_name_full_db_url.value
}

output "SSM_KEY_NAME_DJANGO_SECRET_KEY" {
  value = aws_ssm_parameter.ssm_key_name_django_secret_key.value
}

output "SSM_KEY_NAME_LIMS_SPREADSHEET_ID" {
  value = aws_ssm_parameter.ssm_key_name_lims_spreadsheet_id.value
}

output "SSM_KEY_NAME_LIMS_SERVICE_ACCOUNT_JSON" {
  value = aws_ssm_parameter.ssm_key_name_lims_service_account_json.value
}

output "API_DOMAIN_NAME" {
  value = aws_ssm_parameter.api_domain_name.value
}

output "S3_EVENT_SQS_ARN" {
  value = aws_ssm_parameter.s3_event_sqs_arn.value
}

output "IAP_ENS_EVENT_SQS_ARN" {
  value = aws_ssm_parameter.iap_ens_event_sqs_arn.value
}

output "CERTIFICATE_ARN" {
  value = aws_ssm_parameter.certificate_arn.value
}

output "WAF_NAME" {
  value = aws_ssm_parameter.waf_name.value
}

output "SERVERLESS_DEPLOYMENT_BUCKET" {
  value = aws_ssm_parameter.serverless_deployment_bucket.value
}

output "SLACK_CHANNEL" {
  value = aws_ssm_parameter.slack_channel.value
}

output "SSM_KEY_NAME_IAP_AUTH_TOKEN" {
  value = aws_ssm_parameter.ssm_key_name_iap_auth_token.value
}
