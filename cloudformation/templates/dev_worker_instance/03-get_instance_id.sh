#!/usr/bin/env bash
set -euo pipefail

aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='aws:cloudformation:stack-name'].Value]" \
    --filters "Name=instance-state-name,Values=running"
