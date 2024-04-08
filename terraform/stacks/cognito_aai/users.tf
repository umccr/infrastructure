### NOTE:
# How to provision new Service User to Cognito AAI
#
# This TF resource use Cognito `AdminCreateUser` flow to create new user as an admin. Cognito sends the temporary
# password to designated email address. The user will be created with `FORCE_CHANGE_PASSWORD` state until
# the user sign in and change the password.
#
# AdminCreateUser
# API: https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminCreateUser.html
# CLI: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/cognito-idp/admin-create-user.html
# TF:  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user
#
# Hosted UI
# Couple of ways to get the Cognito Hosted (login) UI page. As follows.
#
# 1) terraform output
# Just run `terraform output` and look for value `portal_client_hosted_ui` in the output.
#
# 2) AWS Console
# Cognito > User pools > data-portal-dev > (select App client) App client: data-portal-app2-dev
#   > at Hosted UI section
#   > View Hosted UI button
#   > (right click & copy link address)
#
# Activating the User
# After terraform apply, please follow the login page once; to reset the password & activate the service user.
#
# Deleting the User
# To avoid confusion, please do not use Cognito Console or AWS CLI (though it is unharmed if you do). It is better to
# deregister through here with terraform. Just simply remove the corresponding block below and terraform apply. Just
# think of as like tracking IAM users being managed in terraform.
###

resource "aws_cognito_user" "orcabus_token_service_user" {
  # Required by https://github.com/umccr/orcabus/pull/197
  user_pool_id             = aws_cognito_user_pool.user_pool.id
  username                 = "orcabus.api.${terraform.workspace}"
  enabled                  = true
  desired_delivery_mediums = ["EMAIL"]

  attributes = {
    email          = "services+orcabus.api.${terraform.workspace}@umccr.org"
    email_verified = true
  }
}
