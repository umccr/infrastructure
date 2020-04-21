#!/usr/bin/env sh

# Usage:
# bash unsub.sh sub.817

curl -s -H "Authorization: Bearer $IAP_AUTH_TOKEN" \
  -X DELETE https://aps2.platform.illumina.com/v1/subscriptions/"$1" | jq
