#!/bin/bash
# NOTE: allocation_id is an external variable filled by Terraform when rendering the script

# mount the stackstorm configuration S3 bucket onto the instance
# TODO: we noticed mount instability, may have to find better (more stable) solution.
#       E.g. mount an EBS volume, or detect and fix mount issues
mkdir "/mnt/stackstorm-data"
s3fs -o iam_role -o allow_other -o mp_umask=0022 umccr-stackstorm-config /mnt/stackstorm-data

# TODO: find better way to get the actual device name
# echo "/dev/xvdf  /mnt/stackstorm-data ext4  defaults,nofail  0  2" >> /etc/fstab
# mount -a

# associate our elastiv IP with the instance
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`sudo cat /var/lib/cloud/data/instance-id`
aws ec2 associate-address --instance-id $instance_id --allocation-id $allocation_id
