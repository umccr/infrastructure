#!/bin/bash

profile_list=("AGHA_SECURITY" "ONBOARDING_SECURITY" "DATABRICKS_SECURITY" "HARTWIG_SECURITY" "ROOT_SECURITY" "TOTHILL_SECURITY" "BASTION_SECURITY" "DEV_SECURITY" "NF_TOWER_SECURITY" "PROD_SECURITY" "STG_SECURITY")


# Check if argument for SecurityHub Control Id exist
if [ -z "$1" ]; then
    echo "Error: Argument for ControlId is missing"
    exit 1
fi
echo "Disabling AWS SecurityHub for Control Id: $1"


# Iterate each profile and apply config
for profile in "${profile_list[@]}"
do
  echo "Updating AWS Profile: $profile"

  account_region=$(aws configure get region --profile "$profile")
  account_number=$(aws sts get-caller-identity --profile "$profile" --query 'Account' --output text)

  aws securityhub update-standards-control \
    --profile  "$profile" \
    --standards-control-arn "arn:aws:securityhub:$account_region:$account_number:control/aws-foundational-security-best-practices/v/1.0.0/$1" \
    --control-status "DISABLED" \
    --disabled-reason "Not relevant for UMCCR's workload"
done
