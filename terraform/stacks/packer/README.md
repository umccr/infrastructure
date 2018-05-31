# packer stack
Use against `dev` only!

```
assume-role dev ops-admin

terraform workspace select dev

terraform ...
```

This Terraform stack provisions AWS resources required for Packer to build our AWS AMIs. This includes the `packer_role` which the `packer` user is allowed to assume to gain permissions within the `dev` account.
It is linked to the assume role policy defined in `bastion` for the `packer` user and has to be applied against the AWS `dev` account only!

**NOTE**: This is used by Travis to automatically build AMIs based on source code changes. If these resources are revoked or changed it may affect these Travis builds.
