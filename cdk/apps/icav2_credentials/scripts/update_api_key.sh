#!/usr/bin/env bash

set -euo pipefail

# Update the API Key

# Valid Accounts
# Dev / Stg / Prod
VALID_ACCOUNTS=(
  "843407916570" \
  "455634345446" \
  "472057503814" \
)

# Pipeline user
# Staging user
# Production user
VALID_API_KEY_SECRET_NAMES=(
  "ICAv2ApiKey-umccr-prod-service-pipelines" \
  "ICAv2ApiKey-umccr-prod-service-staging" \
  "ICAv2ApiKey-umccr-prod-service-production"
)

# Get the secret key name
API_KEY_SECRET_NAME="${1}"

# Get the account id
AWS_ACCOUNT_ID="$( \
  aws sts get-caller-identity --output=json | \
  jq --raw-output \
    '.Account' \
)"

# Check secret name
if [[ ! " ${VALID_API_KEY_SECRET_NAMES[*]} " =~ ${API_KEY_SECRET_NAME} ]]; then
  echo "Error! Not a valid api key secret name" 1>&2
  exit 1
fi

# Check AWS account id
if [[ ! " ${VALID_ACCOUNTS[*]} " =~ ${AWS_ACCOUNT_ID} ]]; then
  echo "Error! Not a valid AWS Account" 1>&2
  exit 1
fi

# Check secret exists
secrets_filter="$( \
  jq --raw-output --compact-output --null-input \
    --arg secret_name "${API_KEY_SECRET_NAME}" \
    '
      {
        "Key": "name",
        "Values": [
          $secret_name
        ]
      }
    '
)"

# List secret
if [[ "$( \
  aws secretsmanager list-secrets \
    --filters "${secrets_filter}" \
    --output json | \
  jq --raw-output \
    '
      .SecretList | length
    ' \
)" -ne 1 ]]; then
  echo "Error! Secret not found" 1>&2
  exit 1
fi

# Update the secret
echo "Enter your API Key:"
read -rs api_key

aws secretsmanager update-secret \
  --secret-id "${API_KEY_SECRET_NAME}" \
  --secret-string "${api_key}"
