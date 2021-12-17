#!/usr/bin/env bash

# Set to fail
set -euo pipefail

# Get json file based on account
account_id="$(aws sts get-caller-identity --output json | jq --raw-output '.Account')"

if [[ "${account_id}" == "843407916570" ]]; then
  echo "Deploying in dev" 1>&2
  params_file="params-dev.json"
elif [[ "${account_id}" == "472057503814" ]]; then
  echo "Deploying in prod" 1>&2
  params_file="params-prod.json"
else
  echo "Could not get params file, please ensure you're logged in to either dev or prod" 1>&2
  exit 1
fi

# Check json file exists
if [[ ! -f "${params_file}" ]]; then
  echo "Error, could not find file '${params_file}'. Exiting" 1>&2
fi

# Get keys
param_keys="$(jq --raw-output 'keys[]' < "${params_file}")"

# Iterate through keys in for loop
for key in ${param_keys}; do
  # Get value
  value="$(jq \
             --raw-output \
             --arg key_name "${key}" '.[$key_name]' \
           < "${params_file}")"

  if aws ssm get-parameter --output json --name "${key}" 1>/dev/null 2>&1; then
    # Get current value in aws ssm
    current_value="$(aws ssm get-parameter --output json --name "${key}" | \
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
    --output json \
    --overwrite \
    --name "${key}" \
    --value "${value}" \
    --type "String"

done
