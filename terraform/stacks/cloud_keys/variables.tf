variable "availability_zone" {
  default = "ap-southeast-2c"
}

variable "stack_name" {
  default = "cloud_keys"
}

################################################################################
## workspace variables

variable "workspace_slack_lambda_arn" {
  type = "map"

  default = {
    prod = "arn:aws:lambda:ap-southeast-2:472057503814:function:bootstrap_slack_lambda_prod"
    dev  = "arn:aws:lambda:ap-southeast-2:620123204273:function:bootstrap_slack_lambda_dev"
  }
}