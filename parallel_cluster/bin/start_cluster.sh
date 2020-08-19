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
        *)
          # Single positional argument
          cluster_name_arg="$1"
        ;;
    esac
    shift
done


# Check config file, set config_file_arg param
if [[ -z "${config_file}" ]]; then
    echo_stderr "--config not specified, defaulting to conf/config"
    config_file="conf/config"
fi

if [[ ! -f "${config_file}" ]]; then
    echo_stderr "Could not find path to config file, exiting"
    exit 1
fi

config_file_arg="--config=${config_file}"

# Check cluster_template argument
if [[ -z "${cluster_template}" ]]; then
    echo_stderr "--cluster-template not specified, using default in config"
    cluster_template_arg=""
else
    cluster_template_arg="--cluster-template=${cluster_template}"
fi

# Check extra parameters argument
if [[ -z "${extra_parameters}" ]]; then
  extra_parameters_arg=""
else
  extra_parameters_arg="--extra-parameters=${extra_parameters}"
fi

# Check no-rollback argument
if [[ "${no_rollback}" == "true" ]]; then
  echo_stderr "--no-rollback specified, use this ONLY when debugging"
  echo_stderr "additional compute nodes cannot be started correctly with this setting"
  no_rollback_arg="--norollback"
else
  no_rollback_arg=""
fi

# Ensure cluster-name is set
if [[ "${cluster_name_arg}" && "${cluster_template_arg}" ]]; then
    # Log what's going to be run
    echo_stderr "Running the following command:"
    echo "pcluster create \
                 ${cluster_name_arg} \
                 ${config_file_arg} \
                 ${no_rollback_arg} \
                 ${cluster_template_arg} \
                 ${extra_parameters_arg} \
                 --tags \"{\\\"Creator\\\": \\\"${USER}\\\"}\"" | \
       sed -e's/  */ /g' 1>&2
    # Initialise the cluster
    pcluster create \
      "${cluster_name_arg}" \
      "${config_file_arg}" \
      "${no_rollback_arg}" \
      "${cluster_template_arg}" \
      "${extra_parameters_arg}" \
      --tags "{\"Creator\": \"${USER}\"}"

    # Check if creation was successful
	  if [[ "$?" == "0" ]]; then
      echo_stderr "Stack creation succeeded - now retrieving name of IP"
      exit 0
    else
      echo_stderr "Could not create the parallel cluster stack, exiting"
      exit 1
    fi

    # Output the master IP to log
    # We list both those in pending/initializing or running states.
    # And we ensure that this is our instance by specifying the Creator tag
    echo_stderr "$(aws ec2 describe-instances \
                     --query "Reservations[*].Instances[*].[InstanceId]" \
                     --filters "Name=instance-state-name,Values=pending,running" \
                               "Name=tag:Name,Values=Master" \
                               "Name=tag:Creator,Values=\"${USER}\"" \
                     --output text)"

	  # FIXME: control error codes better, avoiding counterintuitive ones: i.e authed within a different account:
	  # ERROR: The configuration parameter 'vpc_id' generated the following errors:
	  # The vpc ID 'vpc-7d2b2e1a' does not exist
	  # OR ERROR:  The following resource(s) failed to create: [MasterServerWaitCondition, ComputeFleet].
else
    display_help
fi
