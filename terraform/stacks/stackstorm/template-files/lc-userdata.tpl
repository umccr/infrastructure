#!/bin/bash

mkdir "/mnt/stackstorm_data"
# TODO: find better way to get the actual device name
echo "/dev/xvdf  /mnt/stackstorm_data ext4  defaults,nofail  0  2" >> /etc/fstab
mount -a
