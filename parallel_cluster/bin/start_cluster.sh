#!/bin/sh

display_help() {
    echo "Usage: $0 NAME_OF_YOUR_CLUSTER" >&2
    exit 1
}

if [ "$1" ] ; then
    pcluster create $1 --config conf/config --cluster-template tothill --norollback 
    aws ec2 describe-instances \
             --query "Reservations[*].Instances[*].[InstanceId]" \
             --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=Master" --output text

	# XXX: control error codes better, avoiding counterintuitive ones: i.e authed within a different account:
	# ERROR: The configuration parameter 'vpc_id' generated the following errors:
	# The vpc ID 'vpc-7d2b2e1a' does not exist
    echo "ssm i-XXXXXXXXX away!"
    exit 0
else
    display_help
fi
