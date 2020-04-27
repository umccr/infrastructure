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

output "LAMBDA_IAM_ROLE_ARN" {
    value = "${local.LAMBDA_IAM_ROLE_ARN}"  
}

output "LAMBDA_SUBNET_IDS" {
    value = "${local.LAMBDA_SUBNET_IDS}"  
}

output "LAMBDA_SECURITY_GROUP_IDS" {
    value = "${local.LAMBDA_SECURITY_GROUP_IDS}"  
}

output "SSM_KEY_NAME_FULL_DB_URL" {
    value = "${local.SSM_KEY_NAME_FULL_DB_URL}"  
}

output "SSM_KEY_NAME_DJANGO_SECRET_KEY" {
    value = "${local.SSM_KEY_NAME_DJANGO_SECRET_KEY}"  
}

output "SSM_KEY_NAME_LIMS_SPREADSHEET_ID" {
    value = "${local.SSM_KEY_NAME_LIMS_SPREADSHEET_ID}"
}

output "SSM_KEY_NAME_LIMS_SERVICE_ACCOUNT_JSON" {
    value = "${local.SSM_KEY_NAME_LIMS_SERVICE_ACCOUNT_JSON}"
}

output "API_DOMAIN_NAME" {
    value = "${local.api_domain}"
}

output "S3_EVENT_SQS_ARN" {
    value = "${aws_sqs_queue.s3_event_queue.arn}"
}

output "IAP_ENS_EVENT_SQS_ARN" {
    value = "${aws_sqs_queue.iap_ens_event_queue.arn}"
}

output "CERTIFICATE_ARN" {
    value = "${aws_acm_certificate.client_cert.arn}"
}

output "WAF_NAME" {
    value = "${aws_wafregional_web_acl.api_web_acl.name}"
}

output "SERVERLESS_DEPLOYMENT_BUCKET" {
    value = "${aws_s3_bucket.codepipeline_bucket.bucket}"
}
