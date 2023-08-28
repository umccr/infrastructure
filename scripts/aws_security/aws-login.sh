#!/bin/bash

# The list of all (11) UMCCR accounts
profile_list=("AGHA_SECURITY" "ONBOARDING_SECURITY" "DATABRICKS_SECURITY" "HARTWIG_SECURITY" "ROOT_SECURITY" "TOTHILL_SECURITY" "BASTION_SECURITY" "DEV_SECURITY" "NF_TOWER_SECURITY" "PROD_SECURITY" "STG_SECURITY")

for profile in "${profile_list[@]}"
do
  echo "Logging AWS profile: $profile"
  aws sso login --profile "$profile"
done
