#!/bin/zsh

# Usage:
#   export AWS_PROFILE=unimelb-omics-apse1-admin
#   zsh bootstrap-omics.sh

aws \
  --profile "unimelb-omics-apse1-admin" \
  cloudformation deploy \
  --no-execute-changeset \
  --stack-name CDKToolkit \
  --template-file "$(realpath bootstrap-template.yaml)" \
  --parameter-overrides \
    "TrustedAccounts=442639098081" \
    "TrustedAccountsForLookup=442639098081" \
    'PublicAccessBlockConfiguration=false' \
    'CloudFormationExecutionPolicies=arn:aws:iam::aws:policy/AdministratorAccess' \
    'FileAssetsBucketKmsKeyId=AWS_MANAGED_KEY' \
  --capabilities "CAPABILITY_NAMED_IAM" \
  --tags "Stack=aws_bootstrap"


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

# Note 3:
# At the moment (2024/07) - omics only avail in sudden regions. For us, this has to be Singapore ap-southeast-1.
# Omics exploration happens as pilot phase with long-read project.
# We aren't sure we'll be continue using ap-southeast-1 for long term. Hence, provisioned this dedicated script
# to bootstrap CDK in this ap-southeast-1 region.
# Use case: why we need bootstrap CDK, see https://umccr.slack.com/archives/C02LGHE2G/p1720760221947879
