# AGHA GDR stack

This stack sets up and maintains the basic AWS resources for the AGHA GDR.

NOTE:
- It's resources are supposed to be contained in a separate AWS account, so when applying this stack the corresponding AWS credentials need to be available.
- There is no dev/prod account separation.

The usual Terraform workflow applies:
```
terraform init
terraform plan
terraform apply
```