variable "stack_name" {
  default = "umccr_pipeline"
}

variable "ssm_param_prefix" {
  description = "The path prefix for the SSM parameters used"
  default     = "/umccr_pipeline/novastor/"
}

variable "ssm_role_to_assume_arn" {
  description = "The role to assume to be able to execute SSM RunCommands in the bastion account."
  default     = "arn:aws:iam::383856791668:role/umccr_pipeline_bastion_ssm_role"
}

variable "ssm_run_document_name" {
  description = "The name of the document to execute via SSM RunCommand"
  default     = "UMCCR-RunShellScriptFromStepFunction"
}

################################################################################
# Variables depending on the deployment environment

variable "workspace_notify_slack_lambda_function_name" {
  description = "Name of the Slack notification Lambda."
  type        = "map"

  default = {
    prod = "bootstrap_slack_lambda_prod"
    dev  = "bootstrap_slack_lambda_dev"
  }
}
