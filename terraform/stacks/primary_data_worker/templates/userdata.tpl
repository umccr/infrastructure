#!/bin/bash
set -euxo pipefail # make sure any failling command will fail the whole script

# This script template uses the following placeholders:
#   AGHA_BUCKET   : The bucket to mount to the instance (via s3fs)
#   INSTANCE_TAGS : The tag name/value pairs to associate with this instance

echo "--------------------------------------------------------------------------------"
echo "Provided variables"
echo "${BUCKETS}"
if test -z "${BUCKETS}"; then
  echo "ERROR: Expected variable missing!"
  exit 1
fi


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

sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/epel.repo
yum install -y gcc libstdc++-devel gcc-c++ fuse fuse-devel curl-devel libxml2-devel mailcap automake openssl-devel git
cd /opt
git clone https://github.com/s3fs-fuse/s3fs-fuse
cd s3fs-fuse/
git checkout tags/v1.85
./autogen.sh
./configure --prefix=/usr --with-openssl
make
make install
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
