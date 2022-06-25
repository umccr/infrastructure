# Bastion ECR

This stack creates and maintain ECR repositories as centralised container image store in the Bastion account.

> NOTES:
>   - No terraform workspace required for bastion account

```
export AWS_PROFILE=bastion

terraform workspace list
* default

terraform plan
terraform apply
...
```
