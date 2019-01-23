variable "stack_name" {
  default = "umccr_pipeline"
}

variable "deploy_env" {
  description = "The deployment environment against which to deploy this stack. Select either 'dev' or 'prod'."
}

variable "notify_slack_lambda_function_name" {
  description = "Name of the Slack notification Lambda."
}
