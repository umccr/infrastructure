#!/bin/sh

# Check version
check_pcluster_version() {
  # Used to ensure that pcluster is in our PATH
  pcluster version >/dev/null 2>&1
  return "$?"
}

if ! check_pcluster_version; then
  echo_stderr "Could not get version, from command 'pcluster version'."
  echo_stderr "ensure pcluster is in your path variable"
  exit 1
fi

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
