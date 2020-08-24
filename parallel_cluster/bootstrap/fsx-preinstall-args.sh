#!/usr/bin/env bash

# Base level functions
echo_stderr() {
  echo "${@}" 1>&2
}

# Source config, tells us if we're on a compute or master node
. "/etc/parallelcluster/cfnconfig"

# Globals
FSX_SCRATCH_DIR="/fsx/scratch2"
TIMEZONE="Australia/Melbourne"

# Functions
create_fsx_dir() {
  : '
  Create the fsx directory, change owner to ec2 user
  '
  mkdir -p "${FSX_SCRATCH_DIR}"
}

change_fsx_permissions() {
  : '
  Change fsx permissions s.t entire directory is owned by the ec2-user
  '
  chown ec2-user:ec2-user "${FSX_SCRATCH_DIR}"
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

# Create FSX directory
echo_stderr "Creating mount point for fsx scratch"
create_fsx_dir

# Set /fsx to ec2-user
echo_stderr "Changing ownership of /fsx to ec2-user"
change_fsx_permissions