#!/usr/bin/env bash

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
