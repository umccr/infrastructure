variable "stack_name" {
  default = "uom_administration"
}

variable "aws_billing_read_only_access_policy_arn" {
  default = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

variable "aws_support_access_policy_arn" {
  default = "arn:aws:iam::aws:policy/AWSSupportAccess"
}
