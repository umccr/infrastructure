# Cognito AAI

- This stack is originally break out from Data Portal; and contains AWS Cognito User Pool and Identity Pool. 
- User Pool is used as both AAI and OAuth broker roles for some client application authentication needs.
- Authenticated user can then assume role with web identity through Identity Pool to access some AWS resources.
- Access activities are audited through CloudTrail.

## IdP

User Pool is configured to use UMCCR Google Workspace account as Identity Provider (IdP).

- Go to https://console.developers.google.com/
- Select `umccr-portal` from Project list
- Go to `Credentials > OAuth 2.0 Client IDs > UMCCR Data Portal Client [Dev|Prod|Stg]`

### SSM Parameters

Required to set up SSM parameters as follows.

- Google OAuth Client ID: `/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_id`
- Google OAuth Client Secret: `/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_secret`

```
aws ssm put-parameter --name '/data_portal/dev/google/oauth_client_id' --type "SecureString" --value '<Client ID>'
aws ssm put-parameter --name '/data_portal/dev/google/oauth_client_secret' --type "SecureString" --value '<Client secret>'
```

## Deploy

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
  stg
```

It is typically applied against the AWS `prod`, `dev` or `stg` accounts and uses Terraform workspaces to distinguish between those accounts.

```
terraform workspace select dev
terraform plan
terraform apply
```

## Userland

_which stack use this?_

- Data Portal (both backend and frontend)
- Samplesheet Checker (both backend and frontend)
- Status Page (frontend)
- Illumination v2 (frontend)
- Htsget-RI (backend)

## Usage

### Backend

- For CDK with API Gateway REST and Lambda backend, you can utilise `CognitoUserPoolsAuthorizer`. Code example as follows.
  - https://github.com/umccr/samplesheet-check-backend/blob/6ea644528daf6a0415413e7ee3a68d0727acaaad/stacks/sscheck_backend_stack.py#L111-L131
- Similarly, for CDK with API Gateway on newer HttpApi and Lambda backend, you can utilise Cognito User Pool as `JWT` token issuer. Code example as follows.
  - https://github.com/umccr/infrastructure/blob/83683368bce9d37bf4705a6f6b8b7715c00afc8e/cdk/apps/htsget/htsget/goserver.py#L323-L340
- Otherwise, we have the original [Data Portal API backend in Serverless](https://github.com/umccr/data-portal-apis/blob/909f407841976587375529fab0e05b9c67ca69fa/serverless.yml) framework on how to utilise both JWT and IAM authorizer.

> For end-user documentation, you can leverage [Data Portal API User Guide](https://github.com/umccr/data-portal-apis/tree/dev/docs) on
> - Authorisation flow
> - how to `PORTAL_TOKEN` (JWT bearer token)
> - and/or how to AWS v4 Signature signed request with IAM endpoints

### Frontend

- If you are on _pure_ frontend dev and, in need of authentication, you can utilise this Cognito AAI in conjunction with Amplify framework. Steps are as follows.

  1. Replicate and create a user pool app client like any of the existing app; examples [app_sscheck.tf](app_sscheck.tf) or [app_status_page.tf](app_status_page.tf) or [app_data_portal.tf](app_data_portal.tf)
  2. Register your user pool app client into Identity Pool; _if-only-if_ your client need to access to AWS resources such as SSM Parameters or `execute-api` API Gateway endpoints, etc. Just a need of login/logout authentication alone, you won't need Identity Pool.
  3. Then, you can use Amplify Auth component to code away your client side authentication needs; including OAuth JWT flow and/or; AWS v4 Signature signed request with AWS IAM authorizer authentication flow. 

We have, by now, quite few examples on this such as 
- [Samplesheet Checker](https://github.com/umccr/samplesheet-check-frontend) client, 
- [Status Page](https://github.com/umccr/data-portal-status-page) client, 
- [Illumination v2](https://github.com/umccr/illumination-v2) client; or 
- the original [Data Portal client](https://github.com/umccr/data-portal-client) code itself ... whereas all this Cognito auth pattern is spun off from.
