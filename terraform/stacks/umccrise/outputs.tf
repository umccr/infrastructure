output "workspace" {
  value = "${terraform.workspace}"
}

output "function_name" {
  description = "The name of the Lambda function"
  value       = "${module.lambda.function_name}"
}
