#!/bin/zsh

# we have a config just for our infrastructure scripts
all_config_path=$(realpath "../all-accounts-aws-config.ini")

# list the account (profile name) that wish to bootstrap for CDK - and the corresponding trusted (build) account
typeset -A cdks=(
  'unimelb-toolchain-admin' '442639098081'
  'unimelb-australiangenomics-admin' '442639098081'
  'unimelb-demo-admin' '442639098081'
  'unimelb-beta-admin' '442639098081'
  'unimelb-gamma-admin' '442639098081'
)

# prove we are admin humans in both organisations
#echo "Login with UMCCR AWS credentials"
#AWS_CONFIG_FILE=$all_config_path aws sso login --sso-session umccr
#echo "Login with UniMelb AWS credentials"
#AWS_CONFIG_FILE=$all_config_path aws sso login --sso-session unimelb

# now deploy the CDK template across all listed accounts
for k v ("${(@kv)cdks}");
do
  echo "----------------------------"
  echo "Deploying CDK for account $k"
  AWS_CONFIG_FILE=$all_config_path aws \
                                --profile "$k" \
                                cloudformation deploy \
                                --no-execute-changeset \
                                --stack-name CDKToolkit \
                                --template-file $(realpath bootstrap-template.yaml) \
                                --parameter-overrides \
                                  "TrustedAccounts=$v" \
                                  "TrustedAccountsForLookup=$v" \
                                  'PublicAccessBlockConfiguration=false' \
                                  'CloudFormationExecutionPolicies=arn:aws:iam::aws:policy/AdministratorAccess' \
                                  'FileAssetsBucketKmsKeyId=AWS_MANAGED_KEY' \
                                --capabilities "CAPABILITY_NAMED_IAM" \
                                --tags "Stack=aws_bootstrap"
done

# Note 1:
# At this script stand, it will only create stack changeset and, pause there.
# To apply the changeset, please login to `AWS Console > CloudFormation > CDKToolkit > Change sets (tab) > Execute the change set`
# This is the intentional for now

# Note 2:
# We set PublicAccessBlockConfiguration to false due to UoM role permission issue
# See issue and uom slack thread below
# https://github.com/aws/aws-cdk/issues/8724
# https://unimelb.slack.com/archives/C05A22M4B4L/p1693437379860939
#
# The equivalent of CLI command:  `cdk bootstrap --public-access-block-configuration=false`
