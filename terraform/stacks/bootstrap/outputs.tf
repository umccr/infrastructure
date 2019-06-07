output "workspace" {
  value = "${terraform.workspace}"
}

output "slack_notify_lambda_arn" {
  value = "${module.notify_slack_lambda.function_arn}"
}

output "presigned_urls_username" {
  value = "${module.presigned_urls.username}"
}

output "presigned_urls_access_key" {
  value = "${module.presigned_urls.access_key}"
}

output "presigned_urls_access_secret_key" {
  value = "${module.presigned_urls.encrypted_secret_access_key}"
}