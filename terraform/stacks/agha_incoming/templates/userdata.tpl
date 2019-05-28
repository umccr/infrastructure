#!/bin/bash
set -euxo pipefail # make sure any failling command will fail the whole script

# This script template uses the following placeholders:
#   BUCKETS       : The bucket to mount to the instance (via s3fs)
#   INSTANCE_TAGS : The tag name/value pairs to associate with this instance


echo "--------------------------------------------------------------------------------"
echo "Provided variables"
echo "BUCKETS: ${BUCKETS}"
if test -z "${BUCKETS}"; then
  echo "ERROR: Expected variable missing!"
  exit 1
fi

echo "INSTANCE_TAGS: ${INSTANCE_TAGS}"
if test -z "${INSTANCE_TAGS}"; then
  echo "ERROR: Expected variable missing!"
  exit 1
fi


echo "--------------------------------------------------------------------------------"
echo "Tagging the instance"
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`cat /var/lib/cloud/data/instance-id`
aws ec2 create-tags --resources $instance_id --tags ${INSTANCE_TAGS}


echo "--------------------------------------------------------------------------------"
echo "Prerequisites"
yum update -y


echo "--------------------------------------------------------------------------------"
echo "Set Melbourne timezone"
# set to Melbourne local time
rm /etc/localtime
ln -s /usr/share/zoneinfo/Australia/Melbourne /etc/localtime
ls -al /etc/localtime


echo "--------------------------------------------------------------------------------"
echo "Installing s3fs"
# https://github.com/s3fs-fuse/s3fs-fuse
# TODO: The following is distribution specific (Amazon linux). This could be made more generic.

amazon-linux-extras install -y epel
yum install -y s3fs-fuse
echo "Configuring s3fs"
echo "user_allow_other" | sudo tee -a /etc/fuse.conf


# TODO: don't mount buckets by default
echo "--------------------------------------------------------------------------------"
echo "Mounting buckets with s3fs"
for bucket in ${BUCKETS}
do
  mkdir /mnt/$bucket
  s3fs -o iam_role -o allow_other -o mp_umask=0022 -o umask=0002 $bucket /mnt/$bucket
done

echo "--------------------------------------------------------------------------------"
echo "User data Done."


