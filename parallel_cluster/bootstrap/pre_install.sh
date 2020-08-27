#!/usr/bin/env bash

# Base level functions
echo_stderr() {
  echo "${@}" 1>&2
}

# Source config, tells us if we're on a compute or master node
. "/etc/parallelcluster/cfnconfig"

# Globals
TIMEZONE="Australia/Melbourne"

this_instance_id() {
  : '
  Use the ec2-metadata command to return the instance id this ec2 instance is running on
  Assumes alinux2
  '
  local instance_id
  instance_id="$(ec2-metadata --instance-id | {
    # Returns instance-id: <instance_id>
    # So trim after the space
    cut -d' ' -f2
  })"
  # Return instance id
  echo "${instance_id}"
}

this_cloud_formation_stack_name() {
  : '
  Returns the cloud formation stack
  Single quoetes over query command are intentional
  '
  local cloud_stack
  cloud_stack="$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=$(this_instance_id)" \
    --query='Reservations[*].Instances[*].Tags[?Key==`ClusterName`].Value[]' | {
    # Returns double nested like
    # [
    #  [
    #   "AlexisFSXTest"
    #  ]
    # ]
    jq --raw-output '.[0][0]'
  })"

  # Return cloud stack name
  echo "${cloud_stack}"
}


get_parallelcluster_filesystem_type() {
  # Should be used to edit the following files

  : '
  Use this to choose if we need to set /efs or /fsx as our mount points
  '

  local file_system_types
  file_system_types="$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=$(this_instance_id)" \
    --query='Reservations[*].Instances[*].Tags[?Key==`aws-parallelcluster-filesystem`].Value[]' | {
    # Returns double nested like
    # [
    #  [
    #   "efs=0, multiebs=1, raid=0, fsx=1"
    #  ]
    # ]
    # Turn to
    # efs=0, multiebs=1, raid=0, fsx=1
    jq --raw-output '.[0][0]'
  } | {
    # efs=0, multiebs=1, raid=0, fsx=1
    # Turn To
    # efs=0
    # multiebs=1
    # raid=0
    # fsx=1
    sed 's%,\ %\n%g'
  } | {
    # Run while loop to see if efs=1 or fsx=1
    while read -r LINE; do
      if [[ "${LINE}" == "efs=1" ]]; then
        echo "efs"
        break
      elif [[ "${LINE}" == "fsx=1" ]]; then
        echo "fsx"
        break
      fi
    done
  })"

  # Return filesystem type
  echo "${file_system_types}"
}

filesystem_type="$(get_parallelcluster_filesystem_type)"
if [[ "${filesystem_type}" == "fsx" ]]; then
  SHARED_FILESYSTEM_MOUNT="/fsx"
elif [[ "${filesystem_type}" == "efs" ]]; then
  SHARED_FILESYSTEM_MOUNT="/efs"
else
  # Set /efs as default
  echo_stderr "Warning, couldn't find the type of filesystem we're on"
  echo_stderr "Setting as /efs by default"
  SHARED_FILESYSTEM_MOUNT="/efs"
fi


# Functions
create_shared_dir() {
  : '
  Create the fsx directory, change owner to ec2 user
  '
  mkdir -p "${SHARED_FILESYSTEM_MOUNT}"
}

change_shared_permissions() {
  : '
  Change permissions to /tmp like directory.
  ec2 user now has power to write to its own files created.
  '
  chmod 1777 "${SHARED_FILESYSTEM_MOUNT}"
}

# Runtime installations and configurations
# Processes to complete on ALL (master and compute) nodes at startup

# Security updates
yum update -y

# Set timezone to Australia/Melbourne
timedatectl set-timezone "${TIMEZONE}"

# Start the docker service
systemctl start docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Create /shared directory
echo_stderr "Creating mount point for ${SHARED_FILESYSTEM_MOUNT} scratch"
create_shared_dir

# Set /shared to ec2-user
echo_stderr "Changing ownership of ${SHARED_FILESYSTEM_MOUNT} to ec2-user"
change_shared_permissions