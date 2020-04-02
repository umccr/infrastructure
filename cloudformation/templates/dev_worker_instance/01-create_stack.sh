#!/usr/bin/env bash
set -euo pipefail

aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://worker.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters '[{"ParameterKey": "userName", "ParameterValue": "'"$USER"'"}]'

