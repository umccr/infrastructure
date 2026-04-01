# Supplied via ../accounts.tfvars — run terraform with:
#   terraform plan  -var-file=../accounts.tfvars
#   terraform apply -var-file=../accounts.tfvars
variable "member_accounts" {
  description = "All accounts in this org unit. See ../accounts.tfvars for values and field documentation."
  type = map(object({
    account_id       = string
    cloudtrail_trail = optional(string)
    budget_usd       = optional(number)
    budget_contact   = optional(string)
  }))
}
