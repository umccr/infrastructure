#!/usr/bin/env bash

# Set to fail
set -euo pipefail

# Get keys
param_keys="$(jq --raw-output 'keys[]' < params-dev.json)"

# Iterate through keys in for loop
for key in ${param_keys}; do
  # Get value
  value="$(jq --raw-output --arg key_name "${key}" '.[$key_name]' < params-dev.json)"

  if aws ssm get-parameter --name "${key}" 1>/dev/null 2>&1; then
    # Get current value in aws ssm
    current_value="$(aws ssm get-parameter --name "${key}" | \
                     jq --raw-output \
                       '.Parameter.Value'
                    )"

    # Compare on new value
    if [[ "${current_value}" == "${value}" ]]; then
      echo "Current value for '${key}' is already '${value}', skipping update" 1>&2
      continue
    fi
  fi

  # Put parameter on ssm
  if [[ -n "${current_value-}" ]]; then
    echo "Updating parameter '${key}' from '${current_value}' to '{$value}'" 1>&2
  else
    echo "Setting '${key}' as '${value}'" 1>&2
  fi
  aws ssm put-parameter \
    --overwrite \
    --name "${key}" \
    --value "${value}" \
    --type "String"

done
