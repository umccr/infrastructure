# AGHA CloudFormation Templates

NOTE: Templates may be created with the AWS CloudFormation Designer and therefore carry designer metadata used for the graphical representation of the template.

## agha-worker
NOTE: this template does not yet support user data and therefore starts a basic Amazon Linux AMI, i.e. no S3FS mounts

```bash
# create the stack (and the resouces defined in it)
aws cloudformation create-stack \
    --stack-name agha-worker-1 \
    --template-body file://agha-worker.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters '[{"ParameterKey": "InstanceTypeParameter", "ParameterValue": "t2.medium"}, {"ParameterKey": "InstanceMaxSpotPriceParameter", "ParameterValue": "0.02"}]'
# if parameters are omited, the default instance type will be used: m4.large

# check the status of the stack
aws cloudformation describe-stacks \
    --stack-name agha-worker-1 \
    --query 'Stacks[].[StackStatus,StackName]'

# query for the instance ID
aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='aws:cloudformation:stack-name'].Value]" --filters "Name=instance-state-name,Values=running"

# remove the stack
aws cloudformation delete-stack \
    --stack-name agha-worker-1
```
