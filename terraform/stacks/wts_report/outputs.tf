output "workspace" {
  value = "${terraform.workspace}"
}


# lambda test outputs (development)
output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = "${module.trigger_lambda.function_arn}"
}

output "function_invoke_arn" {
  description = "The ARN of the Lambda function"
  value       = "${module.trigger_lambda.function_invoke_arn}"
}
