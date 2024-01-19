## Databricks secrets CDK stack

Rather than have IAM role passthroughs in ICA to access Athena or the ICA access token, instead we do the following:

### Athena Access

Have an AWS User that can access athena, store credentials in databricks secrets store.

#### CDK Steps 
1. Generate an AWS User and Role that has access to running athena
2. Generate a lambda to run weekly to generate access keys for this AWS User, that are stored as Databricks secrets.

### ICA Access 

Copy over the service user token value from AWS Secrets Manager to Databricks secrets

#### CDK Steps
1. Generate a lambda to run daily to copy the ICA Secret from AWS to Databricks



