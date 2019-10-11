# umccr_data_portal stack

This stack to deploys the AWS resources for the UMCCR data portal.

## Data portal deployment quickstart

```bash
$ terraform init .
$ terraform workspace select prod
$ terraform apply
$ terraform output -json > out.json # Optional
```

### External Dependencies

#### 1. SSM Keys
- Django secrete key: `/${local.stack_name_us}/django_secret_key`
- RDS DB password: `/${local.stack_name_us}/rds_db_password`

#### 2. Secrets Manager
- Google app secret: `google_app_secret`

#### 3. S3 Buckets
- S3 primary data: `${var.s3_primary_data_bucket[terraform.workspace]}`
- LIMS bucket (storing the csv):`${var.lims_bucket[terraform.workspace]}`

#### 4. VPC
- Default VPC in the current region: `${data.aws_vpc.default}` (and subnets and security groups)

#### 5. Github Webhooks

A `GITHUB_TOKEN` env variable is required.

IMPORTANT: If `GITHUB_TOKEN` env var is not defined, it is prompted by Terraform, *BUT*, it will result in a failure similar to this:

```shell
    * aws_codepipeline.codepipeline_apis: 1 error occurred:
    * aws_codepipeline.codepipeline_apis: Error creating CodePipeline: InvalidActionDeclarationException: Action configuration for action 'Source' is missing required configuration 'OAuthToken'
    status code: 400, request id: 9f703a62-9d75-409f-9cc8-3d208546d2b1
```

TODO: Find out why the user input is not properly sanitized?

In order for terraform to create GitHub webhooks, the personal access token
should have `admin:repo_hook` scope at least, and the associated account should
be admin-level user for both repositories (`data-portal-apis` and `data-portal-client`).


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