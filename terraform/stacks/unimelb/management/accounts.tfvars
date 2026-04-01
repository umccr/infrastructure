# Canonical account registry for all sub-stacks of the management account.
#
# Pass this file to every sub-stack:
#   terraform plan  -var-file=../accounts.tfvars
#   terraform apply -var-file=../accounts.tfvars
#
# Fields:
#   account_id       - AWS account ID (required)
#   cloudtrail_trail - trail name if this account sends logs to the central CloudTrail bucket;
#                      null = account has no trail pointing here
#   budget_usd       - monthly cost budget in USD; null = no budget alert for this account
#   budget_contact   - email address for 100%-threshold budget alert; null = email alert disabled

member_accounts = {
  management = {
    account_id       = "363226301494"
    cloudtrail_trail = "mgntTrail"
    budget_usd       = 50
    budget_contact   = "florian.reisinger@umccr.org"
  }
  data = {
    account_id       = "503977275616"
    cloudtrail_trail = "dataTrail"
    budget_usd       = 6000
    budget_contact   = "florian.reisinger@umccr.org"
  }
  montauk = {
    account_id       = "977251586657"
    cloudtrail_trail = "montaukTrail"
    budget_usd       = 50
    budget_contact   = "sehrish.kanwal@umccr.org"
  }
  grimmond = {
    account_id       = "980504796380"
    cloudtrail_trail = null
    budget_usd       = 6000
    budget_contact   = "sehrish.kanwal@umccr.org"
  }
  atlas = {
    account_id       = "550435500918"
    cloudtrail_trail = null
    budget_usd       = 5000
    budget_contact   = "sehrish.kanwal@umccr.org"
  }
  hofmann = {
    account_id       = "465105354675"
    cloudtrail_trail = null
    budget_usd       = 100
    budget_contact   = "ohofmann@umccr.org"
  }
}
