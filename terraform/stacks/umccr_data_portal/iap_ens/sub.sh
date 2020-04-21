#!/usr/bin/env sh

# Usage:
# bash sub.sh subdev.json

curl -s -d "@$1" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $IAP_AUTH_TOKEN" \
  -X POST https://aps2.platform.illumina.com/v1/subscriptions | jq
