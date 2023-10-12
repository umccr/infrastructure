#!/bin/zsh

# we have a config just for our infrastructure scripts
all_config_path=$(realpath "../all-accounts-aws-config.ini")

# specify exactly what accounts we want to bootstrap for CDK - and the corresponding trusted (build) account
typeset -A cdks=(
  'unimelb-australiangenomics' '442639098081'
  'umccr-dev' '383856791668'
)

# prove we are admin humans in both organisations
echo "Login with UMCCR AWS credentials"
AWS_CONFIG_FILE=$all_config_path aws sso login --sso-session umccr-bootstrap-session
echo "Login with UniMelb AWS credentials"
AWS_CONFIG_FILE=$all_config_path aws sso login --sso-session unimelb-bootstrap-session

# now deploy the CDK template across all listed accounts
for k v ("${(@kv)cdks}");
do
  echo "Deploying CDK for account $k"
  AWS_CONFIG_FILE=$all_config_path aws \
                                --profile "$k" \
                                cloudformation deploy \
                                --stack-name CDKToolkit \
                                --template-file $(realpath bootstrap-template.yaml) \
                                --parameter-overrides \
                                  "TrustedAccounts=$v" \
                                  "TrustedAccountsForLookup=$v" \
                                  'PublicAccessBlockConfiguration=false' \
                                  'CloudFormationExecutionPolicies=arn:aws:iam::aws:policy/AdministratorAccess' \
                                  'FileAssetsBucketKmsKeyId=AWS_MANAGED_KEY' \
                                --capabilities "CAPABILITY_NAMED_IAM"
done
