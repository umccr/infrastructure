#!/usr/bin/env bash

# Globals
VALID_AWS_ACCOUNT_IDS=(
  "472057503814" \
  "843407916570"
)
S3_SECRET_ID='PierianDx/S3Credentials'
PIERIANDX_S3_REGION='us-east-1'

# Check if AWS CLI and jq are installed
if ! type aws 2>/dev/null; then
  echo "AWS CLI is not installed. Please install it first."
  exit 1
fi

if ! type jq 2>/dev/null; then
  echo "jq is not installed. Please install it first."
  exit 1
fi

# Check if the user has configured AWS CLI
if ! aws sts get-caller-identity > /dev/null; then
  echo "AWS CLI is not configured. Please configure it first."
  exit 1
fi
account_id="$(
  aws sts get-caller-identity \
    --query "Account" \
    --output text
)"


# Check if the user is in the valid account
if [[ ! " ${VALID_AWS_ACCOUNT_IDS[*]} " =~ ${account_id} ]]; then
  echo "You are not in the valid AWS account. Please switch to the correct account."
  exit 1
fi

# Ask user to enter the email
echo "Enter the s3 access key:"
read -s s3_access_key

# Ask user to enter the password
echo "Enter the s3 secret key:"
read -s s3_secret_key

secrets_json_file="$(mktemp secrets.XXXXXX.json)"

trap 'rm -f "$secrets_json_file"' EXIT

# Generate secrets json file
jq --null-input \
  --raw-output \
  --arg s3_region "${PIERIANDX_S3_REGION}" \
  --arg s3_access_key "${s3_access_key}" \
  --arg s3_secret_key "${s3_secret_key}" \
  '
    {
      s3_region: $s3_region,
      s3_access_key_id: $s3_access_key,
      s3_secret_access_key: $s3_secret_key
    }
  ' > "$secrets_json_file"

# Update secret
echo "Updating api key secret" 1>&2
aws secretsmanager put-secret-value \
  --secret-id "${S3_SECRET_ID}" \
  --secret-string "file://${secrets_json_file}"

echo "Secret updated successfully" 1>&2

# Exit cleanly
trap - EXIT
rm -f "$secrets_json_file"
