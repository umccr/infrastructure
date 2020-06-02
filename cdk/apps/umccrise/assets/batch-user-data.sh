#!/bin/bash
set -euxo pipefail
# Simple user data script to prepare Batch instances for running umccrise jobs
# NOTE: This expects one input parameter, the S3 path to load the umccrise wrapper from
WRAPPER=$1
echo Fetching umccrise wrapper from ${WRAPPER}
echo START CUSTOM USERDATA
ls -al /opt/
mkdir /opt/container
aws s3 cp ${WRAPPER} /opt/container/umccrise-wrapper.sh
ls -al /opt/container/
chmod 755 /opt/container/umccrise-wrapper.sh
ls -al /opt/container/
echo Listing disk devices
lsblk
echo formatting and mounting disk
# assuming the device is available under the requested name
sudo mkfs -t xfs /dev/xvdf
mount /dev/xvdf /mnt
docker info
echo END CUSTOM USERDATA
