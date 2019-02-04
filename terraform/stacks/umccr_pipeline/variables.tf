variable "stack_name" {
  default = "umccr_pipeline"
}


variable "ssm_param_prefix" {
  description = "The path prefix for the SSM parameters used"
  default = "/umccr_pipeline/novastor/"
}

variable "ssm_role_to_assume_arn" {
  description = ""
  default = "arn:aws:iam::383856791668:role/service-role/AmazonEC2RunCommandRoleForManagedInstances"
}

################################################################################
# Variables depending on the deployment environment

variable "workspace_notify_slack_lambda_function_name" {
  description = "Name of the Slack notification Lambda."
  type = "map"
  default = {
    prod = "bootstrap_slack_lambda_prod"
    dev  = "bootstrap_slack_lambda_dev"
  }
}
