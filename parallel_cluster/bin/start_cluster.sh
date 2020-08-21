#!/bin/bash

# Functions
echo_stderr(){
    # Write log to stderr
    echo "${@}" 1>&2
}

display_help() {
    # Display help message then exit
    echo_stderr "Usage: $0 NAME_OF_YOUR_CLUSTER "
    echo_stderr "Additional Options:
                 --cluster-template tothill|umccr_dev (default: tothill)
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
if [[ -n "${extra_parameters}" ]]; then
  pcluster_args="${pcluster_args} --extra-parameters=\"${extra_parameters}\""
fi

# Check no-rollback argument
if [[ "${no_rollback}" == "true" ]]; then
  echo_stderr "--no-rollback specified, use this ONLY when debugging"
  echo_stderr "additional compute nodes cannot be started correctly with this setting"
  pcluster_args="${pcluster_args} --norollback"
fi

# Add creator tag to pcluster args
pcluster_args="${pcluster_args} --tags \"{\\\"Creator\\\": \\\"${USER}\\\"}\""

# Ensure cluster-name is set
if [[ "${cluster_name_arg}" ]]; then
    # Log what's going to be run
    echo_stderr "Running the following command:"
    echo_stderr "pcluster create ${pcluster_args}"
    # Initialise the cluster
    if ! eval pcluster create "${pcluster_args}"; then
      echo_stderr "Could not create the parallel cluster stack, exiting"
      exit 1
    else
      echo_stderr "Stack creation succeeded - now retrieving name of IP"
    fi

    # Output the master IP to log
    # We list both those in pending/initializing or running states.
    # And we ensure that this is our instance by specifying the Creator tag
    instance_id="$(aws ec2 describe-instances \
                     --query "Reservations[*].Instances[*].[InstanceId]" \
                     --filters "Name=instance-state-name,Values=pending,running" \
                               "Name=tag:Name,Values=Master" \
                               "Name=tag:Creator,Values=\"${USER}\"" \
                     --output text)"

    if [[ -z "${instance_id}" ]]; then
      echo_stderr "Could not retrieve instance ID"
    else
      echo_stderr "Got instance_id ${instance_id}"
      echo_stderr "Log into your cluster with \"ssm ${instance_id}\""
    fi

	  # FIXME: control error codes better, avoiding counterintuitive ones: i.e authed within a different account:
	  # ERROR: The configuration parameter 'vpc_id' generated the following errors:
	  # The vpc ID 'vpc-7d2b2e1a' does not exist
	  # OR ERROR:  The following resource(s) failed to create: [MasterServerWaitCondition, ComputeFleet].
else
    display_help
fi
