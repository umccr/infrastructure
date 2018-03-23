#!/bin/bash


# mount the stackstorm configuration onto the instance
mkdir "/mnt/stackstorm-data"
# TODO: we noticed mount instability, may have to find better (more stable) solution.
#       E.g. mount an EBS volume, or detect and fix mount issues
# s3fs -o iam_role -o allow_other -o mp_umask=0022 umccr-stackstorm-config /mnt/stackstorm-data

# TODO: find better way to get the actual device name
echo "/dev/xvdf  /mnt/stackstorm-data ext4  defaults,nofail  0  2" >> /etc/fstab
mount -a

# associate our elastic IP with the instance
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`sudo cat /var/lib/cloud/data/instance-id`
echo "Instance ID: $instance_id"
echo "Allocation ID: $allocation_id"
# NOTE: allocation_id is an external variable filled by Terraform when rendering the script
aws ec2 associate-address --instance-id $instance_id --allocation-id ${allocation_id}
