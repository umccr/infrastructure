# CDK Bootstrap

See story https://trello.com/c/jn56wL6f

CDK can be bootstrapped using the CDK CLI tool. However, subsequent upgrading of the CDK
bootstrap template is prone to error - unless the exact same command line
parameters are specified (including the same trusted accounts etc).

It is much safer if the CDK templates are bootstrapped across all our accounts in a controlled manner
using terraform.

The included `bootstrap-template.yaml` is sourced directly from the CDK project.

Newer versions (it does not change that often) can be obtained from

`https://raw.githubusercontent.com/aws/aws-cdk/main/packages/aws-cdk/lib/api/bootstrap/bootstrap-template.yaml`

and should be saved over the top of the `bootstrap-template.yaml` in this folder.

Check the value `CdkBootstrapVersion` to see which version exists in github and
how it compares to the currently deployed one.


## Workspace

- This stack uses terraform workspace; which in turn map to your `AWS_PROFILE` for target AWS Account.
- Typically, we keep the `default` workspace blank and, it does not contain any deployment to any account.
- Consider; UoM demo in your AWS config as alias to `demo`, then...

```
export AWS_PROFILE=demo
aws sso login
```

> - NOTE: Instead of `yawsso`, you may use any equivalent method that does the same effect. Such as, simply exporting `AWS_*` cred tokens into your environment or, copy short live tokens into `~/.aws/credentials` file. 
> - See https://github.com/hashicorp/terraform/issues/32465

```
yawsso -p demo
```

```
terraform workspace select demo
```

```
terraform workspace list
  default
* demo
```

```
terraform plan
terraform apply
```

### New Workspace

1. First, switch to target account; say `beta` account
```
export AWS_PROFILE=beta
aws sso login
yawsso -p beta
```

2. Create a workspace that correspond to ^^^ account
```
terraform workspace new beta
```

3. List workspace to observe
```
terraform workspace list
```

4. Switch to workspace in "combo" action, e.g.
```
export AWS_PROFILE=beta && terraform workspace select beta
terraform plan
```

5. If you have custom `AWS_PROFILE` naming, then map them accordingly. e.g.
```
export AWS_PROFILE=uom-beta && terraform workspace select beta
```
