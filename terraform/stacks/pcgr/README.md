# pcgr stack
This stack uses workspaces!
This stack uses Vault!

```bash
assume-role-vault dev ops-admin
terraform workspace select dev
terraform init
terraform plan
```

This Terraform stack provisions the AWS infrastructure needed to run our PCGR service. This includes customisations and configurations for UMCCR use cases. It is applied against the AWS `prod` and `dev` accounts and uses Terraform workspaces to distinguish between those accounts.
This stack requires access to Vault, use the `assume-role-vault` wrapper.

If you get access denied errors check that your Terraform workspace corresponds to the account you are operation on. I.e. if you assume the `ops-admin` role of the `dev` account, you have to use the `dev` workspace.

```bash
terraform workspace list
```
