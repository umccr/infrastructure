#!/bin/bash
set -euxo pipefail # make sure any failling command will fail the whole script

# This script template uses the following placeholders:
#   AGHA_BUCKET   : The bucket to mount to the instance (via s3fs)
#   INSTANCE_TAGS : The tag name/value pairs to associate with this instance

echo "--------------------------------------------------------------------------------"
echo "Provided variables"
echo "${AGHA_BUCKET}"
echo "${INSTANCE_TAGS}"
if test -z "${AGHA_BUCKET}" || test -z "${INSTANCE_TAGS}"; then
  echo "ERROR: Expected variable missing!"
  exit 1
fi

echo "--------------------------------------------------------------------------------"
echo "Install dependencies"
apt-get update
apt-get install -y jq



echo "--------------------------------------------------------------------------------"
echo "Set timezone"
# set to Melbourne local time
rm /etc/localtime
ln -s /usr/share/zoneinfo/Australia/Melbourne /etc/localtime
ls -al /etc/localtime



echo "--------------------------------------------------------------------------------"
echo "Configure SSH"
echo "GatewayPorts yes" | tee -a /etc/ssh/sshd_config


echo "--------------------------------------------------------------------------------"
echo "Adding SSH public keys"
# Allows *public* members on UMCCR org to SSH to our AMIs
github_org="UMCCR"

echo "Fetching GitHub SSH keys for $github_org members..."
org_ssh_keys=`curl -s https://api.github.com/orgs/$github_org/members | jq -r .[].html_url | sed 's/$/.keys/'`
for ssh_key in $org_ssh_keys
do
	wget $ssh_key -O - >> /home/ubuntu/.ssh/authorized_keys
done
echo "All SSH keys from $github_org added to the AMI's /home/ubuntu/.ssh/authorized_keys"



echo "--------------------------------------------------------------------------------"
echo "Install awscli"
apt-get install -y python-pip
pip install awscli --upgrade



echo "--------------------------------------------------------------------------------"
echo "Installing s3fs"
# https://github.com/s3fs-fuse/s3fs-fuse
apt-get install -y s3fs

echo "Configuring s3fs"
echo "user_allow_other" | sudo tee -a /etc/fuse.conf



echo "--------------------------------------------------------------------------------"
echo "Mounting bucket with s3fs"
mkdir /mnt/agha_data
s3fs -o iam_role -o allow_other -o mp_umask=0022 -o umask=0002 ${AGHA_BUCKET} /mnt/agha_data



echo "--------------------------------------------------------------------------------"
echo "Tagging the instance"
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`cat /var/lib/cloud/data/instance-id`
aws ec2 create-tags --resources $instance_id --tags ${INSTANCE_TAGS}


