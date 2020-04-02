#!/usr/bin/env bash
set -euo pipefail

aws cloudformation delete-stack --stack-name "$STACK_NAME"
