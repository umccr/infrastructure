#!/usr/bin/env bash

# Get keys
param_keys="$(jq --raw-output 'keys[]' < params-dev.json)"

# Iterate through keys in for loop
for key in ${param_keys}; do
  # Get value
  value="$(jq --raw-output --arg key_name "${key}" '.[$key_name]' < params-dev.json)"

  # Put parameter on ssm
  aws ssm put-parameter \
    --overwrite \
    --name "${key}" \
    --value "${value}" \
    --type "String"

done