#!/bin/bash

# Subs
# AWS vars:
ACCOUNT_ID=${__ACCOUNT_ID__}
REGION=${__REGION__}

# Other global vars
IAP_DOWNLOAD_LINK="https://stratus-documentation-us-east-1-public.s3.amazonaws.com/cli/latest/linux/iap"

# ECR Container vars
EC2_REPO="${!ACCOUNT_ID}.dkr.ecr.${!REGION}.amazonaws.com"
# Write this to /etc/environment for all users
echo "export EC2_REPO=${!EC2_REPO}" >> "/etc/profile.d/ec2_repo.sh"

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
# Make the /data mount a communal playground for all users
chown root:InstanceUser /data
chmod 775 /data

# Add each user to the instance user group so they have access to the /data mount
usermod -a -G InstanceUser ec2-user
usermod -a -G InstanceUser ssm-user

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

# Installing anaconda
echo "Installing anaconda"
ANACONDA_VERSION=2020.02
mkdir -p /opt
wget --quiet https://repo.anaconda.com/archive/Anaconda3-${!ANACONDA_VERSION}-Linux-x86_64.sh
bash Anaconda3-${!ANACONDA_VERSION}-Linux-x86_64.sh -b -p /opt/conda
rm Anaconda3-${!ANACONDA_VERSION}-Linux-x86_64.sh

# Update conda and clean up
/opt/conda/bin/conda update --yes \
  --name base \
  --channel defaults \
	conda
conda clean --all --yes

# Install jupyter so one can launch notebook
conda install --yes --freeze-installed \
  --channel anaconda \
  jupyter
conda clean --all --yes

# Fix bashrc for ec2-user and ssm-user for access ready for conda
su - "ec2-user" -c "/opt/conda/bin/conda init"
su - "ssm-user" -c "/opt/conda/bin/conda init"