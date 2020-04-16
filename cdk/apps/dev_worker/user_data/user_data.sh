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
logger -s "Set EC2_REPO to \"${!EC2_REPO}"

## Fix time
# Set time/logs to melbourne time
ln -sf /usr/share/zoneinfo/Australia/Melbourne /etc/localtime
logger -s "Set time to Melbourne time"

# Put /var on its own partition
mkfs -t ext4 /dev/sdf
# Mount it temporarily under /mnt/var
mkdir /mnt/var
mount /dev/sdf /mnt/var
# Shut down logging temporarily
systemctl stop rsyslog
# Move /var over to tmp mount
# Unmount disk and then remount as /var
rsync --archive --delete /var/ /mnt/var/
umount /dev/sdf
mount /dev/sdf /var
# Delete the invalid mount (/mnt/var)
rm -r /mnt/var
logger -s "Unmounted the /var directory"

# Add disk to fstab
echo "/dev/sdf       /var   ext4    rw,user,suid,dev,exec,auto,async 0       2" >> /etc/fstab
# remount the volume
mount -a

# Since unmounting var we restart the logging service and
# delete the stale sockets.
# https://stackoverflow.com/questions/31964285/how-to-start-or-activate-syslog-socket-in-centos-7
# Remove the stale journal mounts
rm -rf \
  /var/log/journal \
  /var/lib/rsyslog/imjournal.state
# Restart journald and rsyslog services
systemctl restart systemd-journald
systemctl restart rsyslog
logger -s "Successfully remounted var and restarted logging services"

## Now get the /data/ mountpoint
# Create the communal group InstanceUser
groupadd InstanceUser

# create mount point directory for volume
mkdir /data
# create ext4 filesystem on extended volume for data
mkfs -t ext4 /dev/sdg
# add an entry to fstab to mount volume during boot
echo "/dev/sdg       /data   ext4    rw,user,suid,dev,exec,auto,async 0       2" >> /etc/fstab
# mount the volume on current boot
mount -a
logger -s "Mounted the /data directory"

# Make the /data mount a communal playground for all users
chown root:InstanceUser /data
chmod 775 /data
logger -s "/data is a communal playground for all users"

## Update yum
# Clean rpm cache first
if [[ -d "/var/lib/rpm/" ]]; then
  rm -f /var/lib/rpm/__db*
  logger -s "Cleaning rpm cache"
fi
# Then clean yum
yum clean all
logger -s "Cleaning yum"
# Then update yum
yum update -y -q
logger -s "Updating yum"
# Install devtools
yum groups mark install "Development Tools"
yum update -y -q
yum groupinstall -y 'Development Tools'
logger -s "Updated yum and installed the dev tools"

## Stop the ssm client
systemctl stop amazon-ssm-agent
systemctl disable amazon-ssm-agent
logger -s "Stopped the ssm agent so we can update it"
# Install the latest ssm agent
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
# Install / replace ssm agent with latest download
rpm -iv --replacepkgs --force amazon-ssm-agent.rpm
# Delete rpm
rm -f amazon-ssm-agent.rpm
logger -s "Installed the latest ssm agent"

# Started the ssm agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent
logger -s "Restarted the ssm agent"

# Create the ssm user (which is only otherwise created when someone first logs in)
# Should look like this in /etc/passwd
# ssm-user:x:1001:1002::/home/ssm-user:/bin/bash
# Create the ssm-user group
groupadd ssm-user \
  --gid 1002
# Create the ssm-user account
useradd ssm-user \
  --uid 1001 \
  --gid 1002 \
  --shell /bin/bash \
  --base-dir /home/ \
  --create-home
# Give ssm-user an irresponsible level of sudo permission
echo "# Created by user_data.sh" > "/etc/sudoers.d/91-ssm-user.sh"
echo "ssm-user ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers.d/91-ssm-user.sh"

# Create the .ssh directory for the ssm-user before adding authorised keys or adding groups
su - "ssm-user" -c 'mkdir -p --mode 700 /home/ssm-user/.ssh'
logger -s "Created the .ssh directory for the ssm-user"

# Add each user to the instance user group so they have access to the /data mount
usermod -a -G InstanceUser ec2-user
usermod -a -G InstanceUser ssm-user
logger -s "Added users to the InstanceUser group"

# Install docker
amazon-linux-extras install docker
logger -s "Installed docker"
# Add users to docker
usermod -a -G docker ssm-user
usermod -a -G docker ec2-user
logger -s "Added users to docker"

# Start docker container at boot
systemctl start docker
systemctl enable docker
logger -s "Started docker service"

# Install container registry helper
yum install amazon-ecr-credential-helper -y
logger -s "Installed ecr credential helper"

# echo "Fetching GitHub SSH keys for UMCCR members..."
yum install -y jq
ORG_NAME="UMCCR"
ORG_USERS=$(curl -s "https://api.github.com/orgs/${!ORG_NAME}/members" | jq -r ".[].html_url")
for org_user in ${!ORG_USERS}; do
	  wget "${!org_user}.keys" -O - >> "/home/ec2-user/.ssh/authorized_keys"
	  wget "${!org_user}.keys" -O - >> "/home/ssm-user/.ssh/authorized_keys"
done
logger -s "Installed UMCCR public keys"

# Download IAP and install into /usr/local/bin
echo "Downloading IAP"
(cd /usr/local/bin && \
  wget "${!IAP_DOWNLOAD_LINK}" && \
  chmod +x iap)
logger -s "Downloaded IAP"

# Installing anaconda
echo "Installing anaconda"
ANACONDA_VERSION=2020.02
mkdir -p /opt
wget --quiet https://repo.anaconda.com/archive/Anaconda3-${!ANACONDA_VERSION}-Linux-x86_64.sh
bash Anaconda3-${!ANACONDA_VERSION}-Linux-x86_64.sh -b -p /opt/conda
rm Anaconda3-${!ANACONDA_VERSION}-Linux-x86_64.sh
logger -s "Installed Anaconda3"

# Update conda and clean up
/opt/conda/bin/conda update --yes \
  --name base \
  --channel defaults \
	conda
/opt/conda/bin/conda clean --all --yes
logger -s "Updated and cleaned anaconda"

# Install jupyter so one can launch notebook
/opt/conda/bin/conda install --yes --freeze-installed \
  --channel anaconda \
  jupyter \
  pip
/opt/conda/bin/conda clean --all --yes
logger -s "Installed jupyter and pip"

# Install jupyter extensions
/opt/conda/bin/pip install jupyter_contrib_nbextensions
/opt/conda/bin/jupyter contrib nbextension install
logger -s "Installed extensions"

# Fix bashrc for ec2-user and ssm-user for access ready for conda
su - "ec2-user" -c "/opt/conda/bin/conda init"
su - "ssm-user" -c "/opt/conda/bin/conda init"
logger -s "Added conda init to bashrc for users"

# Pull starter notebook into home directory
# FIXME update notebook path once in master branch
starter_notebook="https://raw.githubusercontent.com/alexiswl/umccr-infrastructure/dev_worker_cdk/cdk/apps/dev_worker/dev_worker_notebook.ipynb"
su - "ec2-user" -c "mkdir /home/ec2-user/notebooks"
su - "ssm-user" -c "mkdir /home/ssm-user/notebooks"
# Deploy the notebook from the user
su - "ec2-user" -c "wget \"${!starter_notebook}\" -O - >> \"/home/ec2-user/notebooks/dev_worker.ipynb\""
su - "ssm-user" -c "wget \"${!starter_notebook}\" -O - >> \"/home/ssm-user/notebooks/dev_worker.ipynb\""
logger -s "Added default notebooks into users home directory"

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
logger -s "Added jupyter extensions"