################################################################################
# Get Organisation information
#
# This info can be used to create resource policies sharing to subsets of our accounts.
#

# Use the data source to retrieve the organization details
data "aws_organizations_organization" "current" {}

data "aws_caller_identity" "current" {}

data "aws_organizations_organizational_unit" "production_ou" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
  name      = "production"
}

data "aws_organizations_organizational_unit_descendant_accounts" "production_accounts" {
  parent_id = data.aws_organizations_organizational_unit.production_ou.id
}

data "aws_organizations_organizational_unit" "operational_ou" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
  name      = "operational"
}

data "aws_organizations_organizational_unit_descendant_accounts" "operational_accounts" {
  parent_id = data.aws_organizations_organizational_unit.operational_ou.id
}

data "aws_organizations_organizational_unit" "development_ou" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
  name      = "development"
}

data "aws_organizations_organizational_unit_descendant_accounts" "development_accounts" {
  parent_id = data.aws_organizations_organizational_unit.development_ou.id
}


# output "all_account_ids" {
#   description = "List of all organization account IDs"
#   value       = data.aws_organizations_organization.current.accounts[*].id
# }
#
# output "production_account_ids" {
#   description = "List of all production account IDs (according to OU)"
#   value       = data.aws_organizations_organizational_unit_descendant_accounts.production_accounts.accounts[*].id
# }
#
# output "operational_account_ids" {
#   description = "List of all operational account IDs (according to OU)"
#   value       = data.aws_organizations_organizational_unit_descendant_accounts.operational_accounts.accounts[*].id
# }
#
# output "all_accounts_details" {
#   description = "List of all accounts with details"
#   value       = data.aws_organizations_organization.current.accounts
# }
