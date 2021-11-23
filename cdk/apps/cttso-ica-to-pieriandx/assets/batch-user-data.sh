#!/usr/bin/env bash

: '
Simple user data script to prepare a batch instance for running cttso-ica-to-pieriandx jobs
Expects two arguments as inputs,
first is the s3 path to the pieriandx wrapper script on s3
second is the s3 path to the cloud watch configuration script on s3
'

# Set to fail
set -euo pipefail

# Functions
echo_stderr(){
  : '
  Write output to stderr
  '
  echo "${!@}" 1>&2
}

# Expects two positional arguments
# 1. s3 Path to wrapper
S3_WRAPPER="${__S3_WRAPPER_SCRIPT_URL__}"
# 2. s3 Path to cloud watch configuration
S3_CWA_CONFIG="${__S3_CWA_CONFIG_URL__}"

# GLOBALS
LOCAL_CWA_CONFIG="/opt/aws/cloud-watch-config.json"
LOCAL_WRAPPER="/opt/container/cttso-ica-to-pieriandx-wrapper.sh"

# Check parameters exist
if [[ -z "${!S3_WRAPPER-}" ]]; then
  echo_stderr "Did not get s3 path to wrapper script"
  exit 1
fi

if [[ -z "${!S3_CWA_CONFIG-}" ]]; then
  echo_stderr "Did not get s3 path to cloud watch json"
  exit 1
fi

# Lets do some updates / installations
# Update yum
yum update -q -y
# Install cloud watch agent
yum install -q -y \
  amazon-cloudwatch-agent \
  unzip

# Install docker
amazon-linux-extras install -y \
  docker

# Install aws v2
output_zip_file="awscliv2.zip"
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${!output_zip_file}"
unzip -qq "${!output_zip_file}"
./aws/install
rm "${!output_zip_file}"

# Try loop to retrieve wrapper script
echo_stderr "Fetching cttso-ica-to-pieriandx wrapper from ${!S3_WRAPPER}"
if ! aws s3 cp "${!S3_WRAPPER}" "${!LOCAL_WRAPPER}"; then
  echo_stderr "Could not download ${!S3_WRAPPER} to ${!LOCAL_WRAPPER}"
  exit 1
fi

echo_stderr "Fetching CW Agent Config from ${!S3_CWA_CONFIG}"
# Check if file successfully downloaded
if ! aws s3 cp "${!S3_CWA_CONFIG}" "${!LOCAL_CWA_CONFIG}"; then
  echo_stderr "Could not download ${!S3_CWA_CONFIG} to ${!LOCAL_CWA_CONFIG}"
  exit 1
fi

# Enabling cloud watch agent
echo_stderr "Adding in cloudwatch agent"
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a "append-config" \
  -m "ec2" \
  -s \
  -c "file:${!LOCAL_CWA_CONFIG}"

# Enable docker
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# Create container directory
mkdir -p /opt/container

# Update local wrapper script to be executable by all
chmod 755 "${!LOCAL_WRAPPER}"

# Assuming the device is available under the requested name
sudo mkfs -t xfs /dev/xvdf
mount /dev/xvdf /mnt

# set uid and gid of /mnt/ as the 'cttso_ica_to_pieriandx_user' and group defined in the Dockerfile
chown 1000:1000 /mnt



