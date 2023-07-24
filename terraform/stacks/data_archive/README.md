# data_archive stack

Stack to deploy centralised S3 resources into the `5180-umccr-data` data archival account in UoM AWS. 
This AWS account is meant to be solely use for data archival purpose.

No terraform workspace use.

```
export AWS_PROFILE=data

terraform workspace list
* default

terraform plan
terraform apply
```
