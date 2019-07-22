# umccr_data_portal stack

Stack to deploy AWS resources for UMCCR data portal. 

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
- Glue crawler (one for S3 keys and one for LIMS)
- Glue catalog database and its catalog tables storing crawler input (S3 keys and LIMS)
- S3 bucket storing Athena query results

#### Authentication
- Cognito user pool
  - Cognito app clients (one for current stage, one for localhost)
  - Custom user pool domain (prefix) `data-portal-app-{stage}`
- Cognito identity provider (Google OAuth)
- Cognito identity pool - connecting the identity provider and the two app clients

#### Deployment

- CodePipeline (deploying the APIs): 
    1. Github repo (https://github.com/umccr/data-portal-apis) (through GitHub webhook)
    2. CodeBuild (mainly `serverless create-domain` and `serverless deploy`)
- The custom domain (`api.data-portal.{stage}.umccr.org`) for APIs is deployed through the Serverless frameowork as above, and its certificate is created by Terraform
(see `Others` section)

### 3. Others

- S3 bucket storing both CodePipeline artifacts
- ACM Certificate for subdomain (`*.data-portal.{stage}.umccr.org`)
- The stack also establishes IAM roles and policies where relavent