#!/bin/bash

mkdir "/mnt/stackstorm-data"

s3fs -o iam_role -o allow_other -o mp_umask=0022 umccr-stackstorm-config /mnt/stackstorm-data

<!-- # TODO: find better way to get the actual device name
echo "/dev/xvdf  /mnt/stackstorm-data ext4  defaults,nofail  0  2" >> /etc/fstab
mount -a -->
