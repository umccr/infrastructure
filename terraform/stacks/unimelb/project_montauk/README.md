# README


## Terraform

This account is managed by Terraform. 
See Bootstrap section below if the account has not been bootstrapped yet (only needed once).


```bash

# Make sure to have the correct AWS credentials set up
# Terraform as usual...
terrafrom plan
terraform apply
```


## Bootstrap if the AWS account is new

Before Terraform can be used to manage the resources in the account, we'll run a default bootstrapping process that creates an S3 bucket and a DynamoDB table to manage TF state.

The CW template will use default naming conventions to set up those resources. Those can be overwritten via parameters:

- S3BucketName: the name of the bucket holding the TF State
	Default: `terraform-state-<AWS Account ID>-<AWS region>`
- S3StatePrefix: the prefix to use for the bucket when storing TF state
	Default: `terraform-state`
- DynamoDbTableName: the name of the DynamoDB table to use for stack locking
	Default: `terraform-state-lock`



```bash
# Validate the CloudWatch bootstrap template
aws cloudformation validate-template --template-body file://terraform-bootstrap.yaml

# Make sure to operate on the correct region:
aws configure get region
 
# Then deploy the CloudFormation template 
# NOTE: The flag --no-execute-changeset can be used to dry run the template. 
#       It will not action any changes.
aws cloudformation deploy \
  --template-file terraform-bootstrap.yaml \
  --stack-name terraform-bootstrap \
  --no-execute-changeset
```
