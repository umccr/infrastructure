# bastion stack

```
terraform ...
```


This Terraform stack is mainly used to setup service user accounts, arrange them into groups and define who is allowed to do what across our AWS accounts.

NOTE: This stack is specific to the AWS `bastion` account and only account admins can apply it.

Terraform uses the usual AWS way to retrieve credentials, i.e. either environment variables or a specified profile. Make sure the right credentials are used when working with Terraform.
