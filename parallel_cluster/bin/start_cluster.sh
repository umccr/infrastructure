#!/bin/bash

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

get_local_ip(){
  # Returns the local ip address
  local local_ip
  local_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
  echo "${local_ip}"
}

display_help() {
    # Display help message then exit
    echo_stderr "Usage: $0 NAME_OF_YOUR_CLUSTER "
    echo_stderr "Additional Options:
                 --cluster-template tothill|umccr_dev|umccr_dev_fsx (default: tothill)
                 --config /path/to/config (default: conf/config)
                 --extra-parameters (default: none)
                 --no-rollback (default: false, use for debugging purposes)"

}

# Defaults
no_rollback="false"
pcluster_args=""
cluster_name_arg=""

# Check version
check_pcluster_version() {
  # Used to ensure that pcluster is in our PATH
  pcluster version >/dev/null 2>&1
  return "$?"
}

append_ip_to_extra_parameters() {
  local extra_parameters
  extra_parameters="$(echo "$1" | {
                     # Add AccessFrom attribute - output in raw format
                     jq ".AccessFrom = \"$(get_local_ip)/32\"" \
                       --compact-output
                    } | {
                      # Compact output is too compact
                      # Add space in between colons
                      sed 's/:/: /g'
                    } | {
                      # In between commas also helps readability
                      sed 's/,/, /g'
                    } | {
                      # We need these quotes to be escaped
                      sed 's/"/\\\"/g'
                    })"
  echo "${extra_parameters}"
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

# Get args
while [ $# -gt 0 ]; do
    case "$1" in
        --cluster-template)
          cluster_template="$2"
          shift 1
          ;;
        --config)
          config_file="$2"
          shift 1
          ;;
        --extra-parameters)
          extra_parameters="$2"
          shift 1
          ;;
        --no-rollback)
          no_rollback="true"
          ;;
        --help)
          display_help
          exit 0
          ;;
        '--'*)
          echo_stderr "$1 not a valid argument"
          display_help
          exit 1
          ;;
        *)
          # Single positional argument
          cluster_name_arg="$1"
        ;;
    esac
    shift
done

# Check cluster_name_arg is defined
if [[ -z "${cluster_name_arg}" ]]; then
  echo_stderr "Could not find the one positional argument required."
  echo_stderr "Please specify a name of your cluster"
  display_help
  exit 1
else
  pcluster_args="${pcluster_args} \"${cluster_name_arg}\""
fi

# Check config file, set config_file_arg param
if [[ -z "${config_file}" ]]; then
    echo_stderr "--config not specified, defaulting to conf/config"
    config_file="conf/config"
fi

if [[ ! -f "${config_file}" ]]; then
    echo_stderr "Could not find path to config file, exiting"
    exit 1
fi

# Append config file to arg list
pcluster_args="${pcluster_args} --config=\"${config_file}\""

# Check cluster_template argument
if [[ -z "${cluster_template}" ]]; then
    echo_stderr "--cluster-template not specified, using default in config"
else
    # Append template to arg list
    pcluster_args="${pcluster_args} --cluster-template=\"${cluster_template}\""
fi

# Check extra parameters argument
if [[ -z "${extra_parameters}" ]]; then
  # Initialise extra parameters json
  extra_parameters="{}"
elif ! echo "${extra_parameters}" | jq empty; then
  # Existing jq failed
  echo_stderr "Could not parse \"${extra_parameters}\" into jq. Exiting"
fi

# Add local IP to extra parameters as the only place we can access ssh from
# We don't actually need SSH as we run through ssm
extra_parameters="$(append_ip_to_extra_parameters "${extra_parameters}")"

# Eval mitigation is done in the append_ip_to_extra_parameters command
pcluster_args="${pcluster_args} --extra-parameters \"${extra_parameters}\""

# Check no-rollback argument
if [[ "${no_rollback}" == "true" ]]; then
  echo_stderr "--no-rollback specified, a useful tool for debugging problems"
  pcluster_args="${pcluster_args} --norollback"
fi

# Add creator tag to pcluster args
pcluster_args="${pcluster_args} --tags \"{\\\"Creator\\\": \\\"${USER}\\\"}\""

# Log what's going to be run
echo_stderr "Running the following command:"
eval echo "pcluster create ${pcluster_args}" 1>&2
# Initialise the cluster
if ! eval pcluster create "${pcluster_args}"; then
  echo_stderr "Could not create the parallel cluster stack, exiting"
  exit 1
else
  echo_stderr "Stack creation succeeded - now retrieving name of IP"
fi

# Output the master IP to log
# Use running to ensure it is the current stack
# Use Master to ensure it's the master node
# Use the cloudformation stack-name to ensure we get just this stack
instance_id="$(aws ec2 describe-instances \
                 --query "Reservations[*].Instances[*].[InstanceId]" \
                 --filters "Name=instance-state-name,Values=running" \
                           "Name=tag:Name,Values=Master" \
                           "Name=tag:aws:cloudformation:stack-name,Values=parallelcluster-${cluster_name_arg}" \
                 --output text)"

if [[ -z "${instance_id}" ]]; then
  echo_stderr "Could not retrieve instance ID"
else
  echo_stderr "Got instance_id ${instance_id}"
  echo_stderr "Log into your cluster with \"ssm ${instance_id}\""
fi
