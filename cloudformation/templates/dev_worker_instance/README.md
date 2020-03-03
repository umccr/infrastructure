# CloudFormation template for a worker instance
This template is pre-configured with values (`SecurityGroup` and `Subnet`) specific to the `dev` account, but can be used against other accounts.

This instance will have a volume of customisable size attached and mounted on `/mnt/xvdh`. The instance will also have access to AWS S3 (no bucket lising though):
- read only access to selected `prod` buckets: `aws s3 ls s3://umccr-primary-data-prod/`
- read/write access to `dev` buckets: `aws s3 cp /tmp/foo.txt s3://umccr-misc-temp/foo/`

With the following instructions, you'll need the `worker.yaml` file locally. Either checkout the GitHub repo and navigate to this folder or download the file to a location of your choice.

If someone else has already created a stack with the same name (example below) you should receive an error message similar to:
`An error occurred (AlreadyExistsException) when calling the CreateStack operation: Stack [worker-1] already exists`
You can then either log into the existing instance (please check with the stack creator) or change the stack name and create your own.

Typical usage:
```bash
export STACK_NAME="worker-1"
# create stack and contained resources with defaults (NOTE: userName parameter is mandatory)
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://worker.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters '[{"ParameterKey": "userName", "ParameterValue": "'"$USER"'"}]'

# check stack creation status
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[].[StackStatus,StackName]'

# extract the instance ID
aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='aws:cloudformation:stack-name'].Value]" \
    --filters "Name=instance-state-name,Values=running"

# usually follow with
aws ssm start-session --target i-087645kboff4983

# delete the stack when finished
aws cloudformation delete-stack --stack-name "$STACK_NAME"
```

Other useful commands and command variations:
```bash
# customise the stack (defaults shown, only overwrite the ones you want to change)
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://worker.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters '[{"ParameterKey": "instanceTypeParameter", "ParameterValue": "m4.large"}, {"ParameterKey": "instanceMaxSpotPriceParameter", "ParameterValue": "0.04"}, {"ParameterKey": "instanceDiskSpaceParameter", "ParameterValue": "100"}, {"ParameterKey": "instanceSecurityGroup", "ParameterValue": "sg-c13f6abc"}, {"ParameterKey": "instanceSubnet", "ParameterValue": "subnet-d93b35be"}, {"ParameterKey": "userName", "ParameterValue": "'"$USER"'"}]'


# useful to see the creators of stacks
aws cloudformation describe-stacks \
    --query 'Stacks[].[StackStatus,StackName,Parameters[?ParameterKey==`userName`]]'


# for convenience: save instance ID in env variable
export IID=$(aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId]" \
    --filters Name=tag:Creator,Values=$USER Name=instance-state-name,Values=running "Name=tag:aws:cloudformation:stack-name,Values=$STACK_NAME" \
    | jq -r '.[][][]') && \
    aws ssm start-session --target $IID
```
