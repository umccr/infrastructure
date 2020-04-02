#!/usr/bin/env bash
set -euo pipefail

aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[].[StackStatus,StackName]'
