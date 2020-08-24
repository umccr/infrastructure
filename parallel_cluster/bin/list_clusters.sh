#!/usr/bin/env bash

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
