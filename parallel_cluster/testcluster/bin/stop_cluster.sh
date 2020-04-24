#!/bin/sh

display_help() {
    echo "Usage: $0 NAME_OF_YOUR_CLUSTER" >&2
    exit 1
}

if [ "$1" ] ; then
	echo "Deleting cluster: $1"
	pcluster delete $1 --config conf/config
    exit 0
else
	display_help
fi
