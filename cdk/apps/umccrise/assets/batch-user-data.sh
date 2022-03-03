#!/bin/bash
set -euxo pipefail
# Simple user data script to prepare Batch instances for running umccrise jobs
# NOTE: This expects one input parameter, the S3 path to load the umccrise wrapper from
LOCAL_CWA_CONFIG="/opt/aws/cloud-watch-config.json"
LOCAL_WRAPPER="/opt/container/umccrise-wrapper.sh"
S3_WRAPPER=$1
S3_CWA_CONFIG=$2
echo Fetching umccrise wrapper from ${S3_WRAPPER}
echo Fetching CW Agent Config from ${S3_CWA_CONFIG}
echo START CUSTOM USERDATA
aws s3 cp ${S3_CWA_CONFIG} ${LOCAL_CWA_CONFIG}
yum install -y amazon-cloudwatch-agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a append-config -m ec2 -s -c file:${LOCAL_CWA_CONFIG}
ls -al /opt/
mkdir /opt/container
# Try loop to retrieve wrapper script
waitTime=1
i=0
while [ $i -lt 10 ]; do
       echo "Try: $i"
       aws s3 cp ${S3_WRAPPER} ${LOCAL_WRAPPER}
       if [ $? -ne 0 ]; then     # check exit code of S3 command
       sleep $waitTime           # sleep
       let i+=1                  # increment i
       let waitTime+=2           # increase sleep time on each iteration
       else
               i=10              # break out of loop if exit code is 0
       fi
done
# continue with normal business
ls -al /opt/container/
chmod 755 ${LOCAL_WRAPPER}
ls -al /opt/container/
echo Listing disk devices
lsblk
echo formatting and mounting disk
# assuming the device is available under the requested name
sudo mkfs -t xfs /dev/xvdf
mount /dev/xvdf /mnt
# set uid and gid of /mnt/ as the 'umccrise' user and group defined in the Umccrise Dockerfile
chown 1000:1000 /mnt
docker info
echo END CUSTOM USERDATA
