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

# Start docker container at boot
systemctl start docker
systemctl enable docker

# Install container registry helper
yum install amazon-ecr-credential-helper -y

# Install the latest ssm agent
yum install -y \
  https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent

# echo "Fetching GitHub SSH keys for UMCCR members..."
yum install -y jq
ORG_NAME="UMCCR"
ORG_USERS=$(curl -s "https://api.github.com/orgs/${!ORG_NAME}/members" | jq -r ".[].html_url")
for org_user in ${!ORG_USERS}; do
	  wget "${!org_user}.keys" -O - >> "/home/ec2-user/.ssh/authorized_keys"
	  wget "${!org_user}.keys" -O - >> "/home/ssm-user/.ssh/authorized_keys"
done

# Add configuration to docker config - this logs us into docker for our ecr - doesn't seem to work right now.
#su - "ec2-user" -c 'mkdir -p $HOME/.docker && echo "{ \"credsStore\" : \"ecr-login\" }" >> $HOME/.docker/config.json'
#su - "ssm-user" -c 'mkdir -p $HOME/.docker && echo "{ \"credsStore\" : \"ecr-login\" }" >> $HOME/.docker/config.json'

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
/opt/conda/bin/conda clean --all --yes

# Install jupyter so one can launch notebook
/opt/conda/bin/conda install --yes --freeze-installed \
  --channel anaconda \
  jupyter \
  pip

/opt/conda/bin/conda clean --all --yes

# Install jupyter extensions
/opt/conda/bin/pip install jupyter_contrib_nbextensions
/opt/conda/bin/jupyter contrib nbextension install

# Fix bashrc for ec2-user and ssm-user for access ready for conda
su - "ec2-user" -c "/opt/conda/bin/conda init"
su - "ssm-user" -c "/opt/conda/bin/conda init"

# Pull starter notebook into home directory
# FIXME update notebook path once in master branch
starter_notebook="https://raw.githubusercontent.com/alexiswl/umccr-infrastructure/dev_worker_cdk/cdk/apps/dev_worker/dev_worker_notebook.ipynb"
su - "ec2-user" -c "mkdir /home/ec2-user/notebooks"
su - "ssm-user" -c "mkdir /home/ssm-user/notebooks"

# Deploy the notebook from the user
su - "ec2-user" -c wget "${!starter_notebook}" -O - >> "/home/ec2-user/notebooks/dev_worker.ipynb"
su - "ssm-user" -c wget "${!starter_notebook}" -O - >> "/home/ssm-user/notebooks/dev_worker.ipynb"

# Add the notebook configs (with git control)
# FIXME update the notebook path once in the master branch
starter_notebook_configs="https://raw.githubusercontent.com/alexiswl/umccr-infrastructure/dev_worker_cdk/cdk/apps/dev_worker/user_data/add_notebook_configs.sh"
# Get the notebook config for the user
su - "ec2-user" -c "wget \"${!starter_notebook_configs}\" -O - >> \"/home/ec2-user/add_notebook_configs.sh\""
su - "ssm-user" -c "wget \"${!starter_notebook_configs}\" -O - >> \"/home/ssm-user/add_notebook_configs.sh\""
# Install configs
su - "ec2-user" -c "bash \"/home/ec2-user/add_notebook_configs.sh\""
su - "ssm-user" -c "bash \"/home/ssm-user/add_notebook_configs.sh\""
# Delete script
su - "ec2-user" -c "rm \"/home/ec2-user/add_notebook_configs.sh\""
su - "ssm-user" -c "rm \"/home/ssm-user/add_notebook_configs.sh\""
