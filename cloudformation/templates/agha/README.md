# AGHA CloudFormation Templates

NOTE: Templates may be created with the AWS CloudFormation Designer and therefore carry designer metadata used for the graphical representation of the template.

## agha-worker
NOTE: this template does not yet support user data and therefore starts a basic Amazon Linux AMI, i.e. no S3FS mounts

```bash
aws cloudformation create-stack \
    --stack-name agha-worker-1 \
    --template-body file://cf-template-agha-worker-1.json \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters '[{"ParameterKey": "InstanceTypeParameter", "ParameterValue": "t2.medium"}, {"ParameterKey": "InstanceMaxSpotPriceParameter", "ParameterValue": "0.02"}]'
# if parameters are omited, the default instance type will be used: m4.large

aws cloudformation describe-stacks \
    --stack-name agha-worker-1 \
    --query 'Stacks[].[StackStatus,StackName]'
```