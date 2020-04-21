# Data Portal IAP ENS Subscription

### TL;DR

- Check existing subscriptions
    ```
    curl -s -H "Authorization: Bearer $IAP_AUTH_TOKEN" -X GET https://aps2.platform.illumina.com/v1/subscriptions | jq
    ```
- Sub/unsub 
    ```
    node expr.js
    cp subdev.sample.json subdev.json
    bash sub.sh subdev.json
    bash unsub.sh sub.817
    ```
- There is no support for PATCH or PUT request. So just delete and recreate subscriptions as if need updating it.
