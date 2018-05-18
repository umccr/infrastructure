# bootstrap stack
This stack uses workspaces!

```
assume-role dev ops-admin

terraform workspace select dev

terraform ...
```

This Terraform stack sets up some initial AWS infrastructure that needs to be in place before other stacks can be used. It is applied against the AWS `prod` and `dev` accounts and uses Terraform workspaces to distinguish between those accounts.

If you get access denied errors check that your Terraform workspace corresponds to the account you are operation on. I.e. if you assume the `ops-admin` role of the `dev` account, you have to use the `dev` workspace.

```
terraform workspace list
```

NOTE: This stack does **not** use state locking as it is setting up the required DynamoDB table!

NOTE: This stack requires **one AWS account per workspace**! If two workspaces refer to the same AWS account you will run into resource name clashes.
