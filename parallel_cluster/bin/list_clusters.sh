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

get_master_ec2_from_pcluster_id() {
  local cluster_id="$1"
  local master_server_key="MasterServer"
  local instance_cut_column="3"  # Add one since double spacing between items
  local ncolumns="2"
  pcluster instances "${cluster_id}" \
    --region "${REGION}" | \
  column -s"${SEP}" -t -c"${ncolumns}" | \
  grep "${master_server_key}" | \
  cut -d"${SEP}" -f"${instance_cut_column}"
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
N_COLUMNS=4
SEP=" "

# Get clusters as an array
mapfile -t clusters_array <<< "$(pcluster list -r "${REGION}")"

# Initialise lines to print out
lines=("Name Status Version MasterServer")

# For each line, which currently contains the name, status and version,
# obtain the master instance of the stack
# then append this to the line and then that line to the array of lines to print out
for cluster_row in "${clusters_array[@]}"; do
  cluster_id="$(cut -d' ' -f1 <<< "${cluster_row}")"
  master_ec2_instance="$(get_master_ec2_from_pcluster_id "${cluster_id}")"
  lines+=("${cluster_row}  ${master_ec2_instance}")
done

# Pipe into column to print out all lines.
column -s"${SEP}" -t -c "${N_COLUMNS}" <<< "$(printf '%s\n' "${lines[@]}")"
