output "workspace" {
  value = "${terraform.workspace}"
}

/*
output "underlying_ecs_cluster" {
  value = "${module.compute_env.underlying_ecs_cluster}"
}
*/

# lambda test outputs (development)
output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = "${module.lambda.function_arn}"
}

output "function_invoke_arn" {
  description = "The ARN of the Lambda function"
  value       = "${module.lambda.function_invoke_arn}"
}

output "function_name" {
  description = "The name of the Lambda function"
  value       = "${module.lambda.function_name}"
}

output "role_arn" {
  description = "The ARN of the IAM role created for the Lambda function"
  value       = "${module.lambda.role_arn}"
}

output "role_name" {
  description = "The name of the IAM role created for the Lambda function"
  value       = "${module.lambda.role_name}"
}

output "api_id" {
  description = "The API ID"
  value = "${aws_api_gateway_rest_api.lambda_rest_api.id}"
}

output "resource_id" {
  value = "${aws_api_gateway_resource.lambda_resource.id}"
}

output "parent_id" {
  value = "${aws_api_gateway_rest_api.lambda_rest_api.root_resource_id}"
}