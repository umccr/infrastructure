variable "stack_name" {
  description = "The name of this stack. Will be used to tag/name resources."
  default     = "umccr_pipeline_bastion"
}

variable "dev_sfn_role_arn" {
  description = ""
  default     = "arn:aws:iam::620123204273:role/umccr_pipeline_state_machine_dev"
}

variable "prod_sfn_role_arn" {
  description = ""
  default     = "arn:aws:iam::472057503814:role/umccr_pipeline_state_machine_prod"
}
