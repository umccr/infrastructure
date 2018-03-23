#!/bin/bash
sudo apt-get update

echo "--------------------------------------------------------------------------------"
echo "Set timezone"
# set to Melbourne local time
sudo rm /etc/localtime
sudo ln -s /usr/share/zoneinfo/Australia/Melbourne /etc/localtime
sudo ls -al /etc/localtime



echo "--------------------------------------------------------------------------------"
echo "Install awscli"
sudo apt-get install -y python-pip
pip install awscli --upgrade

# TODO: see if we can set this via IAM profiles
export AWS_DEFAULT_REGION=ap-southeast-2



echo "--------------------------------------------------------------------------------"
echo "Installing s3fs"
# https://github.com/s3fs-fuse/s3fs-fuse
sudo apt-get install -y automake autotools-dev fuse g++ git libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config

cd /tmp/
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse
./autogen.sh
./configure
make
sudo make install

echo "Configuring s3fs"

echo "user_allow_other" | sudo tee -a /etc/fuse.conf



# echo "--------------------------------------------------------------------------------"
# echo "Installing rexray"
# ##### REX-Ray (not needed for the docker plugins)
# # https://rexray.readthedocs.io/en/stable/user-guide/installation/
# cd /tmp/
# curl -sSL https://rexray.io/install | sh -s -- stable
