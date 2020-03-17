#!/bin/bash

# Subs
# AWS vars:
ACCOUNT_ID=${__ACCOUNT_ID__}
REGION=${__REGION__}

# Other global vars
IAP_DOWNLOAD_LINK="https://stratus-documentation-us-east-1-public.s3.amazonaws.com/cli/latest/linux/iap"

# ECR Container vars
EC2_REPO="${!ACCOUNT_ID}.dkr.ecr.${!REGION}.amazonaws.com/"
# Write this to /etc/environment for all users
echo "export EC2_REPO=${!EC2_REPO}" >> "/etc/environment"

## Fix time
# Set time/logs to melbourne time
ln -sf /usr/share/zoneinfo/Australia/Melbourne /etc/localtime

# Put /var on its own partition
mkfs -t ext4 /dev/sdf
# Mount it temporarily under /mnt/var
mkdir /mnt/var
mount /dev/sdf /mnt/var
# Go to single-user mode so we have no read/write activity
# Move /var over to tmp mount
# Unmount disk and then remount as /var
rsync --archive --delete /var/ /mnt/var/
umount /dev/sdf
mount /dev/sdf /var
# Delete the invalid mount (/mnt/var)
rm -r /mnt/var

# Add disk to fstab
echo "/dev/sdf       /var   ext4    rw,suid,dev,exec,auto,user,async,nofail 0       2" >> /etc/fstab
# mount the volume on current boot
mount -a

## Now get the /data/ mountpoint
# Create the communal group InstanceUser
groupadd InstanceUser
# create mount point didrectory for volume
mkdir /data
# create ext4 filesystem on extended volume for data
mkfs -t ext4 /dev/sdg
# add an entry to fstab to mount volume during boot
echo "/dev/sdg       /data   ext4    rw,suid,dev,exec,auto,user,async,nofail 0       2" >> /etc/fstab
# mount the volume on current boot
mount -a

# create a user folder for both users on this directory
mkdir /mnt/xvdh/ssm-user
mkdir /mnt/xvdh/ec2-user

# change the owner so the user (via SSM) has access
chown -R ssm-user /mnt/xvdh/ssm-user
chown -R ec2-user /mnt/xvdh/ec2-user

## Update yum
yum update -y -q
yum groups mark install "Development Tools"
yum update -y -q
yum groupinstall -y 'Development Tools'

# Install docker
amazon-linux-extras install docker

# Add users to docker
usermod -a -G docker ssm-user
usermod -a -G docker ec2-user

# Start docker container
service docker start

# Install container registry helper
yum install amazon-ecr-credential-helper -y

# Add configuration to docker config - this logs us into docker for our ecr
su - "ec2-user" -c 'mkdir -p $HOME/.docker && echo "{ \"credsStore\" : \"ecr-login\" }" >> $HOME/.docker/config.json'
su - "ssm-user" -c 'mkdir -p $HOME/.docker && echo "{ \"credsStore\" : \"ecr-login\" }" >> $HOME/.docker/config.json'

# Download IAP and install into /usr/local/bin
echo "Downloading IAP"
(cd /usr/local/bin && \
  wget "${!IAP_DOWNLOAD_LINK}" && \
  chmod +x iap)