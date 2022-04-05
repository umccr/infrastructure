# UMCCR Authentication Stack

This stack prepare AWS Cognito User Pool for application that require authentication via UMCCR google account (@umccr.org).  


This stack are configured to work on localy at http://localhost:3000. This will make sure that Cognito User Pool will work despite of app deployed locally.

## Usage

This stack provide you with some variables for the AWS Cognito User pool setup that can be used in your app via SSM Parameter. The following are the list of variables.
- Cognito User Pool Id: `/umccr_auth/cog_user_pool_id`
- Cognito oauth domain: `/umccr_auth/oauth_domain`
- Cognito clientId Local: `/umccr_auth/cog_app_client_id_local`

_For local deployment, the oauth_redirect in and out would be http://localhost:3000_


You can add more ClientApp to the Cognito User Pool via CDK or Terraform in your app. There are example on how to add this below.

#### Terraform

```hcl-terraform
# -*- coding: utf-8 -*-
#
# Note: sscheck or sample sheet check app reuse some Portal TF created resources
# such as Cognito. This streamlines integrate UI login to the same authority.

locals {
  app_name = "a-cool-app"
  app_name_us = "a_cool_app"

  sub_domain = "status.data"

  base_domain = {
    prod = "prod.umccr.org"
    dev  = "dev.umccr.org"
  }

  app_domain = "${local.sub_domain}.${local.base_domain[terraform.workspace]}"

  alias_domain = {
    prod = "a-cool-app.umccr.org"
    dev  = ""
  }

  app_callback_urls = {
    prod = ["https://${local.app_domain}", "https://${local.alias_domain[terraform.workspace]}"]
    dev  = ["https://${local.app_domain}"]
  }

  app_oauth_redirect_url = {
    prod = "https://${local.alias_domain[terraform.workspace]}"
    dev  = "https://${local.app_domain}"
  }

  ssm_client_prefix = "/${app_name_us}/client"
}

################################################################################
# Query for Pre-configured SSM Parameter Store (UserPoolId)

data "aws_ssm_parameter" "cog_user_pool_id" {
  name  = "/umccr_auth/cog_user_pool_id"
}

################################################################################

# Cool app client
resource "aws_cognito_user_pool_client" "cool_app_client" {
  name                         = "${local.app_name}-app-${terraform.workspace}"
  user_pool_id                 = data.aws_ssm_parameter.cog_user_pool_id.value
  supported_identity_providers = ["Google"]

  callback_urls = local.app_callback_urls[terraform.workspace]
  logout_urls   = local.app_callback_urls[terraform.workspace]

  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  id_token_validity = 24

  # Need to explicitly specify this dependency
  depends_on = [aws_cognito_identity_provider.identity_provider]
}

resource "aws_ssm_parameter" "cool_app_client_id_stage" {
  name  = "${local.cool_client_prefix}/cog_app_client_id_stage"
  type  = "String"
  value = aws_cognito_user_pool_client.cool_app_client.id
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "cool_oauth_redirect_in_stage" {
  name  = "${local.app_client_prefix}/oauth_redirect_in_stage"
  type  = "String"
  value = local.app_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}

resource "aws_ssm_parameter" "app_oauth_redirect_out_stage" {
  name  = "${local.app_client_prefix}/oauth_redirect_out_stage"
  type  = "String"
  value = local.app_oauth_redirect_url[terraform.workspace]
  tags  = merge(local.default_tags)
}
```
##### Workspaces

Login to AWS.
```
aws sso login --profile=dev && export AWS_PROFILE=dev
```

This stack uses terraform workspaces.
```
terraform workspace list
  default
* dev
  prod
```

It is typically applied against the AWS `prod` and `dev` accounts and uses Terraform workspaces to distinguish between those accounts.

```
terraform workspace select dev
terraform plan
terraform apply
```


#### CDK

Similarly for CDK, you can use [`from_user_pool_id`](https://docs.aws.amazon.com/cdk/api/v2/python/aws_cdk.aws_cognito/UserPool.html#aws_cdk.aws_cognito.UserPool.from_user_pool_id) function from cognito and add new client to the cognito pool.

```python
from aws_cdk import (
    Stack,
    aws_cognito as cognito,
    aws_ssm as ssm
)
from constructs import Construct


class SomeStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)


        umccr_cognito_user_pool_id = ssm.StringParameter.from_string_parameter_attributes(
          self, "UmccrCognitoUserPoolId",
          parameter_name="/umccr_auth/cog_user_pool_id"
        ).string_value

        umccr_cognito_user_pool = cognito.UserPool.from_user_pool_id(
          self, 
          "UmccrCognitoUserPool", 
          umccr_cognito_user_pool_id)

        umccr_cognito_user_pool.add_client("app-client",
            o_auth=cognito.OAuthSettings(
                flows=cognito.OAuthFlows(
                    authorization_code_grant=True
                ),
                scopes=[cognito.OAuthScope.OPENID],
                callback_urls=["https://my-app-domain.com/welcome"],
                logout_urls=["https://my-app-domain.com/signin"]
            )
        )
)
        
```
