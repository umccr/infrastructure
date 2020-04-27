#!/bin/sh

display_help() {
    echo "Usage: $0 NAME_OF_YOUR_CLUSTER" >&2
    exit 1
}

if [ "$1" ] ; then
    pcluster create $1 --config conf/config --cluster-template tothill
    aws ec2 describe-instances \
             --query "Reservations[*].Instances[*].[InstanceId]" \
             --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=Master" --output text

    echo "ssm i-XXXXX away!"
    exit 0
else
    display_help
fi
