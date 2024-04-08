#!/usr/bin/env bash

# Globals
VALID_AWS_ACCOUNT_IDS=(
  "472057503814" \
  "843407916570"
)
API_SECRET_ID='PierianDx/ApiKey'
JWT_SECRET_ID='PierianDx/JwtKey'
JWT_SECRET_COLLECTOR_FUNCTION_NAME='collectPierianDxAccessToken'

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
echo "Enter the email address of the user you want to add to the AWS account:"
read email

# Ask user to enter the password
echo "Enter the password for the user:"
read -s password

# Get institution
if [[ $account_id == "472057503814" ]]; then
  institution="melbourne"  # Prod
elif [[ $account_id == "843407916570" ]]; then
  institution="melbournetest"  # Dev
fi

secrets_json_file="$(mktemp secrets.XXXXXX.json)"

trap 'rm -f "$secrets_json_file"' EXIT

# Generate secrets json file
jq --null-input \
  --raw-output \
  --arg email "$email" \
  --arg password "$password" \
  --arg institution "$institution" \
  '
    {
      email: $email,
      password: $password,
      institution: $institution
    }
  ' > "$secrets_json_file"

# Update secret
echo "Updating api key secret" 1>&2
aws secretsmanager put-secret-value \
  --secret-id "${API_SECRET_ID}" \
  --secret-string "file://${secrets_json_file}"
  
echo "Secret updated successfully" 1>&2

# Rotate JWT
echo "Rotating JWT" 1>&2
aws secretsmanager rotate-secret \
  --secret-id "${JWT_SECRET_ID}"

# Wait a second
sleep 10

# Collect newly rotated JWT Secret
echo "Collecting newly rotated JWT Secret" 1>&2
access_token="$( \
  response_json="$(mktemp response.XXXXXX.json)"
  aws lambda invoke \
    --invocation-type "RequestResponse" \
    --function-name "${JWT_SECRET_COLLECTOR_FUNCTION_NAME}" \
    --payload '{}' \
    response_json \
    1>/dev/null;
  cat response_json | \
  jq -r;
  rm -f "$response_json"
)"

echo "${access_token}" | wc -c


# Exit cleanly
trap - EXIT
rm -f "$secrets_json_file"
