#!/bin/bash
set -euxo pipefail # make sure any failling command will fail the whole script

echo "--------------------------------------------------------------------------------"
echo "Remove unnecessary ssh, sendmail and portmap servers"
yum remove -y openssh-server sendmail portmap
echo "--------------------------------------------------------------------------------"


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


# echo "--------------------------------------------------------------------------------"
# echo "Installing s3fs"
# # https://github.com/s3fs-fuse/s3fs-fuse

# sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/epel.repo
# yum install -y gcc libstdc++-devel gcc-c++ fuse fuse-devel curl-devel libxml2-devel mailcap automake openssl-devel git
# cd /opt
# git clone https://github.com/s3fs-fuse/s3fs-fuse
# cd s3fs-fuse/
# git checkout tags/v1.85
# ./autogen.sh
# ./configure --prefix=/usr --with-openssl
# make
# make install
# echo "Configuring s3fs"
# echo "user_allow_other" | sudo tee -a /etc/fuse.conf


# TODO: don't mount buckets by default
# echo "--------------------------------------------------------------------------------"
# echo "Mounting buckets with s3fs"
# for bucket in ${BUCKETS}
# do
#   mkdir /mnt/$bucket
#   s3fs -o iam_role -o allow_other -o mp_umask=0022 -o umask=0002 $bucket /mnt/$bucket
# done


echo "--------------------------------------------------------------------------------"
echo "Installing conda, bioinfo tools and other practical "poke-around" basics"
# https://www.anaconda.com/rpm-and-debian-repositories-for-miniconda/

# Import our gpg public key
rpm --import https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc

# Add the Anaconda repository
cat <<EOF > /etc/yum.repos.d/conda.repo

[conda]
name=Conda
baseurl=https://repo.anaconda.com/pkgs/misc/rpmrepo/conda
enabled=1
gpgcheck=1
gpgkey=https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc
EOF

# Install regular and conda+bioinfo pkgs
yum install -y git tmux conda

# Install in both SSM user and EC2-USER, since some users might login via SSH instead of SSM...
. /opt/conda/etc/profile.d/conda.sh

#for awsuser in ssm-user ec2-user
for awsuser in ssm-user
do
  echo ". /opt/conda/etc/profile.d/conda.sh && conda activate umccr" >> /home/$awsuser/.bashrc
  runuser -l $awsuser -c "conda create -y -n umccr"
  runuser -l $awsuser -c "conda install -n umccr -y -c conda-forge -c bioconda bcftools openssl vcflib bedtools htslib pythonpy samtools vawk"
done

echo "--------------------------------------------------------------------------------"
echo "User data Done."
