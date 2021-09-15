#!/bin/bash

bucket=$1
key=$2

aws s3 ls s3://$bucket/$key
if test "$?" -ne 0; then
  echo "Object does not exist: $key!"
  exit 1
fi

aws s3api put-object-tagging \
    --bucket $bucket \
    --key $key \
    --tagging '{"TagSet": [{ "Key": "Consent", "Value": "True" }]}'