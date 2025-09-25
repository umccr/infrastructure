Terraform Stack for Security account
================================================================================

This Stack manages the resources in the security account.


AWS account
--------------------------------------------------------------------------------

- account org  : AWS UMCCR organisation
- account name : security
- account id   : 266735799852

Note: see [bootstrapping](#account-bootstrapping-one-off) for initial account setup (only requird once)


Terraform
--------------------------------------------------------------------------------

Manage project (AWS) infrastructure, like data bucket(s), IAM users/roles, etc...

This stack does not use terraform workspaces. See Terraform files for details, start with [main.tf](./main.tf).

```bash
# Make sure to have the correct AWS credentials set up
# Terraform as usual...
terraform plan
terraform apply
```



Account Bootstrapping (one-off)
--------------------------------------------------------------------------------

The bootstrapping is only required once.

The Terraform configuration requires an S3 bucket to record the infrastucture state and for state locking.

The CloudFormation template will use default naming conventions to set up those resources. If need be, those can be overwritten via parameters:

- S3BucketName: the name of the bucket holding the TF State
	Default: `terraform-state-<AWS Account ID>-<AWS region>`


```bash
# Validate the CloudWatch bootstrap template
aws cloudformation validate-template --template-body file://terraform-bootstrap.yaml

# Make sure to operate on the correct region:
aws configure get region
 
# Then deploy the CloudFormation template 
# NOTE: The flag --no-execute-changeset can be used to dry run the template. 
#       It will not action any changes. Remove it for the actual bootstrap.
aws cloudformation deploy \
  --template-file terraform-bootstrap.yaml \
  --stack-name terraform-bootstrap \
  --no-execute-changeset
```


Then update the `main.tf` file with the bucket name. 

