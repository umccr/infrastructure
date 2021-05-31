# UMCCR Data Portal Stack

This stack deploys the AWS resources for the UMCCR data portal.

## Quickstart

1. For a fresh start, **prepare prerequisites** as described section below
2. Then _rinse and spin_ terraform as usual
    ```bash
    $ terraform init .
    $ terraform workspace list
    $ terraform workspace select dev
    $ terraform plan
    $ terraform apply
    $ terraform output -json > out.json # Optional
    ```

### Prerequisites

#### SSM Keys

Need to create deployment environment specific secret parameters as follows.

1. Django Secret Key: `/${local.stack_name_us}/${terraform.workspace}/django_secret_key`
2. RDS DB Username: `/${local.stack_name_us}/${terraform.workspace}/rds_db_username`
3. RDS DB Password: `/${local.stack_name_us}/${terraform.workspace}/rds_db_password`
4. Google OAuth Client ID: `/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_id`
5. Google OAuth Client Secret: `/${local.stack_name_us}/${terraform.workspace}/google/oauth_client_secret`
6. Google LIMS Spreadsheet ID: `/${local.stack_name_us}/${terraform.workspace}/google/lims_spreadsheet_id`
7. Google LIMS Service Account JSON: `/${local.stack_name_us}/${terraform.workspace}/google/lims_service_account_json`

e.g. For `dev` environment
```
aws ssm put-parameter --name '/data_portal/dev/django_secret_key' --type "SecureString" --value '<Django Secret Key>'
aws ssm put-parameter --name '/data_portal/dev/rds_db_username' --type "SecureString" --value '<DB Admin Username>'
aws ssm put-parameter --name '/data_portal/dev/rds_db_password' --type "SecureString" --value '<Secure Password>'
aws ssm put-parameter --name '/data_portal/dev/google/oauth_client_id' --type "SecureString" --value '<Client ID>'
aws ssm put-parameter --name '/data_portal/dev/google/oauth_client_secret' --type "SecureString" --value '<Client secret>'
aws ssm put-parameter --name '/data_portal/dev/google/lims_service_account_json' --type "SecureString" --value file://umccr-portal-123456789abc.json
aws ssm put-parameter --name '/data_portal/dev/google/lims_spreadsheet_id' --type "SecureString" --value '<Spreadsheet ID>'
```

You can check existing parameter, example as follows.
```
aws ssm get-parameter --name '/data_portal/dev/rds_db_password' | jq
aws ssm get-parameter --name '/data_portal/dev/rds_db_password' --with-decryption | jq -r .Parameter.Value
```

### Post Deployment

#### Certificate Validation

If `var.alias_domain` is configured for additional domain to alias `var.base_domain`, and the `var.alias_domain`'s Route53 hosted zone is in different account (e.g. bastion), then terraform script will just create/request the certificate in ACM and, it will be pending DNS validation. Please follow up with [DNS certificate validation through ACM Console UI](https://aws.amazon.com/blogs/security/easier-certificate-validation-using-dns-with-aws-certificate-manager/) to respective Route53 zones. See also notes on `var.certificate_validation` and `client_cert_dns` for further details.

### Destroy

* Before tear down terraform stack, follow [API Serverless stack Destroy](https://github.com/umccr/data-portal-apis#destroy) section to remove Serverless stack, first!
* Then, run `terraform destroy`

#### Caveat 

Terraform and AWS in general, when recycling resources like ACM certificate with associated CloudFront distribution, S3 bucket with versioned-objects and, RDS snapshots or RDS instance with delete protection, then terraform destroy may fail. Because these resources still hold association with their counterpart resources -- which, for some reason, have not clear yet or this is by-design protection. In this case, purge/untangle these resources through Console UI, then re-run terraform destroy until it has become success. For example:

```
Error: Error applying plan:

1 error occurred:
	* aws_s3_bucket.client_bucket (destroy): 1 error occurred:
	* aws_s3_bucket.client_bucket: error deleting S3 Bucket (umccr-data-portal-client-dev): BucketNotEmpty: The bucket you tried to delete is not empty
	status code: 409, request id: D2156698BB748933, host id: l+Z1DMnaCeFqQtaXRufoLt1wpO3a7VMi7KQXXmigZuNbYnV9I73uqkDUNzyGHlAp0xYeTb+9XaY=
```


## Stack Overview

### 1. React App (client/front end)

- S3 bucket storing compiled JS code

#### Accessbility

- CloudFront distribution connecting the public to the private S3 Bucket (above)
- Custom domain - `data-portal.{stage}.umccr.org` and ACM certificate (and validation)

#### Deployment

- CodePipeline (deploying the front end): 
   1. GitHub repo (https://github.com/umccr/data-portal-client) (through GitHub webhook)
   2. CodeBuild (mainly `npm build` and `aws s3 sync`)

### 2. APIs (back end)

#### Data
- S3 primary data bucket: used to create SQS event notification
- LIMS data bucket.
- RDS cluster: MySQL database

#### Authentication
- Cognito user pool
  - Cognito app clients (one for current stage, one for localhost)
  - Custom user pool domain (prefix) `data-portal-app-{stage}`
- Cognito identity provider (Google OAuth)
- Cognito identity pool - connecting the identity provider and the two app clients

#### VPC
- VPC for the backend, separate from the default VPC
- Three subnets in different availability zone
- VPC Endpoints:
  - SSM Interface for parameter access (from lambda)
  - S3 Gateway for LIMS data access (from lambda)
- Security Groups:
  - RDS and Lambda are in separate groups so that Lambda can access RDS
  - One for RDS, enabling MySQL inbound requests (from Lambda)
  - One for Lambda

#### Deployment

- CodePipeline (deploying the APIs): 
    1. Github repo (https://github.com/umccr/data-portal-apis) (through GitHub webhook)
    2. CodeBuild (mainly `serverless create-domain` and `serverless deploy`)
- The custom domain (`api.data.{stage}.umccr.org`) for APIs is deployed through the Serverless frameowork as above, and its certificate is created by Terraform
(see `Others` section)

### 3. Others

- S3 bucket storing both CodePipeline artifacts
- ACM Certificate for subdomain (`*.data.{stage}.umccr.org`)
- The stack also establishes IAM roles and policies where relavent
- Web Application Firewall including SQL injection protection (on query strings)

#### LIMS data processing
- If we ever want to rewrite the LIMS data (and S3 keys data is at production
scale), we need to run the rewrite function in an EC2 instance so long running time is allowed.
- Currently we need to manually configure an EC2 instance:
   - AMI: Amazon Linux AMI 2018.03.0 (HVM), SSD Volume Type
   - Install following packages in the EC2 instance:
     - python36 (as the default python in the instance is python 2)
     - git - so that we can pull from the backend repository 
   - Once above has been set, go to the backend code directory, and install
     the python dependencies, via `pip-3.6 install -r requirements.txt`
   - To run the LIMS rewrite function, run 
     `python-3.6 manage.py lims_rewrite --csv_bucket_name [bucket name] 
     --csv_key [csv file name]`