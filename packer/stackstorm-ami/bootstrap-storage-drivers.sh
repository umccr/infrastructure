#!/bin/sh

sudo apt-get update

echo "--------------------------------------------------------------------------------"
echo "Installing s3fs"
##### s3fs
# https://github.com/s3fs-fuse/s3fs-fuse
# used to mount the S3 bucket with the st2 config to the instance 
sudo apt-get install -y automake autotools-dev fuse g++ git libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config

cd /tmp/
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse
./autogen.sh
./configure
make
sudo make install

echo "--------------------------------------------------------------------------------"
echo "Configuring s3fs"

echo "user_allow_other" | sudo tee -a /etc/fuse.conf


#
# ##### REX-Ray (not needed for the docker plugins)
# # https://rexray.readthedocs.io/en/stable/user-guide/installation/
# cd /tmp/
# curl -sSL https://rexray.io/install | sh -s -- stable


echo "--------------------------------------------------------------------------------"
echo "Install awscli"

sudo apt-get install -y python-pip
pip install awscli --upgrade
