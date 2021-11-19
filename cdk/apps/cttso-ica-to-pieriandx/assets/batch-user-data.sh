#!/usr/bin/env bash

: '
Simple user data script to prepare a batch instance for running cttso-ica-to-pieriandx jobs
Expects two arguments as inputs,
first is the s3 path to the pieriandx wrapper script on s3
second is the s3 path to the cloud watch configuration script on s3
'

# Set to fail
set -euxo pipefail

# Functions
echo_stderr(){
  : '
  Write output to stderr
  '
  echo "${@}" 1>&2
}

# GLOBALS
LOCAL_CWA_CONFIG="/opt/aws/cloud-watch-config.json"
LOCAL_WRAPPER="/opt/container/cttso-ica-to-pieriandx-wrapper.sh"
WAIT_TIME="5"  # Seconds


# Expects two positional arguments
# 1. s3 Path to wrapper
S3_WRAPPER="$1"
# 2. s3 Path to cloud watch configuration
S3_CWA_CONFIG=$2

# Check parameters exist
if [[ -z "${S3_WRAPPER-}" ]]; then
  echo_stderr "Did not get s3 path to wrapper script"
  exit 1
fi

if [[ -z "${S3_CWA_CONFIG-}" ]]; then
  echo_stderr "Did not get s3 path to cloud watch json"
  exit 1
fi

# Try loop to retrieve wrapper script
echo_stderr "Fetching cttso-ica-to-pieriandx wrapper from ${S3_WRAPPER}"
counter=0
while [[ "${counter}" -lt "10" ]]; do
       echo_stderr "Download Attempt: $counter"
       if ! aws s3 cp "${S3_WRAPPER}" "${LOCAL_WRAPPER}"; then
         echo_stderr "Download failed, retrying installation"
         sleep "${WAIT_TIME}"
         counter="$((counter + 1))"
       else
         break
       fi
done

# Check if file successfully downloaded
if [[ ! -f "${LOCAL_WRAPPER}" ]]; then
  echo_stderr "Could not download ${S3_WRAPPER} to ${LOCAL_WRAPPER}"
  exit 1
fi

echo_stderr "Fetching CW Agent Config from ${S3_CWA_CONFIG}"

# Check if file successfully downloaded
if ! aws s3 cp "${S3_CWA_CONFIG}" "${LOCAL_CWA_CONFIG}"; then
  echo_stderr "Could not download ${S3_CWA_CONFIG} to ${LOCAL_CWA_CONFIG}"
  exit 1
fi

# Lets do some updates / installations
# Update yum
yum update -q -y
# Install cloud watch agent
yum install -q -y \
  amazon-cloudwatch-agent
# Install docker
amazon-linux-extras install -y \
  docker

# Install aws v2
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -qq awscliv2.zip
./aws/install
rm "awscliv2.zip"

# Enabling cloud watch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a "append-config" \
  -m "ec2" \
  -s \
  -c "file:${LOCAL_CWA_CONFIG}"

# Enable docker
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# Create container directory
mkdir -p /opt/container

# Update local wrapper script to be executable by all
chmod 755 "${LOCAL_WRAPPER}"

# Assuming the device is available under the requested name
sudo mkfs -t xfs /dev/xvdf
mount /dev/xvdf /mnt

# set uid and gid of /mnt/ as the 'cttso_ica_to_pieriandx_user' and group defined in the Dockerfile
chown 1000:1000 /mnt



