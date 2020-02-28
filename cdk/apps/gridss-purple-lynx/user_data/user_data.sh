# Set vars
REF_DATA_BUCKET="s3://umccr-misc-temp/gridss_hg19_refdata/hg19/"
REF_DATA_DIR="/mnt/xvdh/hg19_gridss_ref_data/"

## Fix time
# Set time/logs to melbourne time
ln -sf /usr/share/zoneinfo/Australia/Melbourne /etc/localtime

## Fix mountpoints
# create mount point directory
mkdir /mnt/xvdh
# create ext4 filesystem on new volume
mkfs -t ext4 /dev/xvdh
# add an entry to fstab to mount volume during boot
echo "/dev/xvdh       /mnt/xvdh   ext4    rw,suid,dev,exec,auto,user,async,nofail 0       2" >> /etc/fstab
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

# Move docker folder to larger diskspace
mv /var/lib/docker /mnt/xvdh/docker

# Link mount to docker container
ln -s /mnt/xvdh/docker /var/lib/docker

# Add users to docker
usermod -a -G docker ssm-user
usermod -a -G docker ec2-user

# Start docker container
service docker start

# Sync gridss data from s3 bucket
aws s3 sync --quiet "${REF_DATA_BUCKET}" "${REF_DATA_DIR}"

# Install container registry helper
yum install amazon-ecr-credential-helper -y

# Add configuration to docker config - this logs us into docker for our ecr
su - "ec2-user" -c 'mkdir -p $HOME/.docker && echo "{ \"credsStore\" : \"ecr-login\" }" >> $HOME/.docker/config.json'