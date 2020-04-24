#!/bin/sh

display_help() {
    echo "Usage: $0 NAME_OF_YOUR_CLUSTER" >&2
    exit 1
}

if [ "$1" ] ; then
	echo "Creating cluster: $1"
	pcluster create $1 --config conf/config --cluster-template tothill
    exit 0
else
	display_help
fi
