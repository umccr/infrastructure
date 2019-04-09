output "workspace" {
  value = "${terraform.workspace}"
}

# lambda test outputs (development)
output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = "${module.cloud_keys_lambda.function_arn}"
}

output "function_name" {
  description = "The name of the Lambda function"
  value       = "${module.cloud_keys_lambda.function_name}"
}

output "role_arn" {
  description = "The ARN of the IAM role created for the Lambda function"
  value       = "${module.cloud_keys_lambda.role_arn}"
}

output "role_name" {
  description = "The name of the IAM role created for the Lambda function"
  value       = "${module.cloud_keys_lambda.role_name}"
}