# CloudFormation template for a worker instance
This template is pre-configured with values (`SecurityGroup` and `Subnet`) specific to the `dev` account, but can be used against other accounts.

This instance will have a volume of customisable size attached and monted on `/mnt/xvdh`. The instance will also have access to AWS S3 (no bucket lising though):
- read only access to selected `prod` buckets: `aws s3 ls s3://umccr-primary-data-prod/`
- read/write access to `dev` buckets: `aws s3 cp /tmp/foo.txt s3://umccr-misc-temp/foo/`

```bash
# create stack and contained resources (providing the mandatory user name from env variable)
aws cloudformation create-stack \
    --stack-name worker-1 \
    --template-body file://worker.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters '[{"ParameterKey": "userName", "ParameterValue": "'"$USER"'"}]'

# create stack with custom parameters (defaults shown, only overwrite the ones you want to change)
aws cloudformation create-stack \
    --stack-name worker-1 \
    --template-body file://worker.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters '[{"ParameterKey": "instanceTypeParameter", "ParameterValue": "m4.large"}, {"ParameterKey": "instanceMaxSpotPriceParameter", "ParameterValue": "0.04"}, {"ParameterKey": "instanceDiskSpaceParameter", "ParameterValue": "100"}, {"ParameterKey": "instanceSecurityGroup", "ParameterValue": "sg-c13f6abc"}, {"ParameterKey": "instanceSubnet", "ParameterValue": "subnet-d93b35be"}, {"ParameterKey": "userName", "ParameterValue": "'"$USER"'"}]'

# check stack creation status
aws cloudformation describe-stacks \
    --stack-name worker-1 \
    --query 'Stacks[].[StackStatus,StackName]'

# extract the instance ID
aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='aws:cloudformation:stack-name'].Value]" \
    --filters "Name=instance-state-name,Values=running"

# usually follow with
# aws ssm start-session --target i-087645kboff4983

# delete the stack when finished
aws cloudformation delete-stack --stack-name worker-1
```