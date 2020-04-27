#!/bin/sh

display_help() {
    echo "Usage: $0 NAME_OF_YOUR_CLUSTER" >&2
    exit 1
}

if [ "$1" ] ; then
	pcluster delete $1 --config conf/config
    exit 0
else
	display_help
fi
