# bootstrap stack

> DEPRECATION NOTICE:
> 
> This bootstrap stack has been deprecated from all environments.
> 
> To note; the `dev` workspace mentioned in the original README below, belong to our "old_dev" account which has been decommissioned.
> See https://github.com/umccr/wiki/tree/main/computing/cloud/amazon#decommissioned-umccr
> 
> For `prod` workspace, it belongs to our usual `umccr_production` account, of which, we have removed the terraform states controlled by this stack. As follows.

```
terraform workspace list
terraform workspace select prod

(bucket)
terraform state rm aws_s3_bucket.primary_data
terraform state rm aws_s3_bucket.raw-sequencing-data
terraform state rm aws_s3_bucket.run-data
terraform state rm aws_s3_bucket.validation_data
terraform state rm aws_s3_bucket_policy.fastq_data
terraform state rm aws_s3_bucket_policy.validation_bucket_policy
terraform state rm aws_s3_bucket_public_access_block.fastq_data
terraform state rm aws_s3_bucket_public_access_block.primary_data
terraform state rm aws_s3_bucket_public_access_block.raw-sequencing-data
terraform state rm aws_s3_bucket_public_access_block.run-data
terraform state rm aws_s3_bucket_public_access_block.validation_data

(dynamo)
terraform state rm aws_dynamodb_table.dynamodb-terraform-lock
```

> All remainder resources have been tear down as follows from `prod` workspace.

```
terraform destroy
```

> Hence, no AWS resources controlled by this terraform stack anymore.
> This stack itself will be removed from this Git repo in next routine clean up.

---

~~This stack uses workspaces!~~

```bash
terraform workspace select dev
terraform ...
```

~~This Terraform stack sets up some initial AWS infrastructure that needs to be in place before other stacks can be used. It is applied against the AWS `prod` and `dev` accounts and uses Terraform workspaces to distinguish between those accounts.~~

~~If you get access denied errors check that your Terraform workspace corresponds to the account you are operation on. I.e. if you assume the `ops-admin` role of the `dev` account, you have to use the `dev` workspace.~~

```bash
terraform workspace list
```

~~NOTE: This stack does **not** use state locking as it is setting up the required DynamoDB table!~~

~~NOTE: This stack requires **one AWS account per workspace**! If two workspaces refer to the same AWS account you will run into resource name clashes.~~
