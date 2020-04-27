#!/bin/sh

display_help() {
    echo "Usage: $0 NAME_OF_YOUR_CLUSTER" >&2
    exit 1
}

if [ "$1" ] ; then
    pcluster create $1 --config conf/config --cluster-template tothill
    aws ec2 describe-instances --filters Name=instance-state-name,Values="running" \
                               --query 'Reservations[].Instances[].{Instance:InstanceId}'
    echo "ssm i-XXXXX away!"
    exit 0
else
    display_help
fi
