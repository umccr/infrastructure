#!/bin/bash
set -eo pipefail
# Follow procedure from AWS blog:
# https://aws.amazon.com/blogs/security/how-to-rotate-access-keys-for-iam-users/

if [ "$1" = "--debug" ]; then
  echo "With debug output..."
fi

username=$(aws iam get-user | jq -r '.User.UserName')
if [ "$1" = "--debug" ]; then
  echo "Username: $username"
fi

# get the current/old access key record
old_record=$(aws iam list-access-keys --user-name "$username")
if [ "$1" = "--debug" ]; then
  echo "Current records:"
  echo "$old_record"
fi
old_access_key=$(echo "$old_record" | jq -r '[.AccessKeyMetadata[] | {AccessKeyId,Status} | select(.Status="Active")] | limit(1;.[].AccessKeyId)')
if [ "$1" = "--debug" ]; then
  echo "Old access key: $old_access_key"
fi

# create a new access key
new_record=$(aws iam create-access-key --user-name "$username")
new_access_key=$(echo "$new_record" | jq -r '.AccessKey.AccessKeyId')
new_secret_access_key=$(echo "$new_record" | jq -r '.AccessKey.SecretAccessKey')

aws iam update-access-key --access-key-id "$old_access_key" --status Inactive --user-name "$username"

# temporarily disable current AWS profile, so new creds can be tested
unset AWS_PROFILE

# export new creds
export AWS_ACCESS_KEY_ID="$new_access_key"
export AWS_SECRET_ACCESS_KEY="$new_secret_access_key"
export AWS_DEFAULT_REGION="ap-southeast-2"

# test the new access key
sleep 10  # new creds need some time to get active
test_result=$(aws s3 ls s3://agha-gdr-store/)
if [ "$1" = "--debug" ]; then
  echo "Output of credentials test (list bucket):"
  echo "$test_result"
fi

# delete the old access key
aws iam delete-access-key --access-key-id "$old_access_key" --user-name "$username"

echo "New access credentials:"
echo "aws_access_key_id = $new_access_key"
echo "aws_secret_access_key = $new_secret_access_key"
