#!/usr/bin/env bash

# Functions
echo_stderr(){
    # Write log to stderr
    echo "${@}" 1>&2
}

has_creds(){
  : '
  Are credentials present on CLI
  '
  aws sts get-caller-identity >/dev/null 2>&1
  return "$?"
}

# Check version
check_pcluster_version() {
  # Used to ensure that pcluster is in our PATH
  pcluster version >/dev/null 2>&1
  return "$?"
}

if ! has_creds; then
    echo_stderr "Could not find credentials, please login to AWS before continuing"
    exit 1
fi

if ! check_pcluster_version; then
  echo_stderr "Could not get version, from command 'pcluster version'."
  echo_stderr "ensure pcluster is in your path variable"
  exit 1
fi

# Need to list region
# Hard code in for now
REGION="ap-southeast-2"

# Column params
N_COLUMNS=3
SEP=" "

# Get clusters
clusters="$(pcluster list -r "${REGION}")"

# Write out clusters
echo -e "Name  Status  Version \n${clusters}" | \
  column -s "${SEP}" -t -c "${N_COLUMNS}"
