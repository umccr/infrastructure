# Welcome to your CDK TypeScript project

This is a blank project for CDK development with TypeScript.

The `cdk.json` file tells the CDK Toolkit how to execute your app.

## Useful commands

* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `cdk deploy`      deploy this stack to your default AWS account/region
* `cdk diff`        compare deployed stack with current state
* `cdk synth`       emits the synthesized CloudFormation template


```
## Clear cache
localstack stop
rm -rf ~/.cache/localstack

## Start localstack
localstack start -d

## Start bootstrap
cdklocal bootstrap

# Add required ssm parameters
awslocal ssm put-parameter --name  "/slack/webhook/host" --value "my-value" --type String
awslocal ssm put-parameter --name "/slack/webhook/id" --value "my-value" --type SecureString --overwrite

## Deploy localstack
cdklocal deploy icav2-credentials-test-workflow-deployment-role-localstack
```