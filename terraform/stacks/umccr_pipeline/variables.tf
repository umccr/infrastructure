variable "stack_name" {
  default = "umccr_pipeline"
}


variable "ssm_param_prefix" {
  description = "The path prefix for the SSM parameters used"
  default = "/umccr_pipeline/novastor/"
}

################################################################################
# Variables depending on the deployment environment

variable "deploy_env" {
  description = "The deployment environment against which to deploy this stack. Select either 'dev' or 'prod'."
}

variable "notify_slack_lambda_function_name" {
  description = "Name of the Slack notification Lambda."
}
