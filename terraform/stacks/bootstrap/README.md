# bootstrap stack

```
assume-role prod ops-admin

terraform init

terraform workspace select prod

terraform plan

terraform apply
```

This Terraform stack sets up some initial AWS infrastructure that needs to be in place before other stacks can be used. It is applied against the AWS `prod` and `dev` accounts and uses Terraform workspaces to distinguish between those accounts.

If you get access denied errors check that your Terraform workspace corresponds to the account you are operation on. I.e. if you assume the `ops-admin` role of the `dev` account, you have to use the `dev` workspace.

```
terraform workspace list
```

NOTE: This stack does **not** use state locking as it is setting up the required DynamoDB table!
