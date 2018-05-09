#!/bin/bash

################################################################################
# shut down docker service, since we are going to overwrite /var/lib/docker
echo "Stopping docker"
sudo systemctl stop docker
sudo rm -rf /var/lib/docker/volumes/* /var/lib/docker/volumes/.*


################################################################################
# mount the stackstorm configuration volume and docker volume onto the instance
echo "Creating mount points"
mkdir "/mnt/stackstorm-data"
#mkdir "/mnt/stackstorm-docker"

# TODO: find better way to get the actual device name
echo "/dev/xvdf  /mnt/stackstorm-data ext4  defaults,nofail  0  2" >> /etc/fstab
#echo "/dev/xvdg  /mnt/stackstorm-docker ext4  defaults,nofail  0  2" >> /etc/fstab
echo "/dev/xvdg  /var/lib/docker/volumes ext4  defaults,nofail  0  2" >> /etc/fstab
sudo mount -a

################################################################################
# restart docker service
echo "Restarting docker"
sudo systemctl start docker


################################################################################
# associate our elastic IP with the instance
echo "Associating public address"
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`cat /var/lib/cloud/data/instance-id`
echo "Instance ID: $instance_id"
echo "Allocation ID: ${allocation_id}"
# NOTE: allocation_id is an external variable filled by Terraform when rendering the script
aws ec2 associate-address --instance-id $instance_id --allocation-id ${allocation_id}


################################################################################
# start the DataDog agent
dd_api_key=${datadog_apikey}
echo "Starting DataDog agent"
my_hostname="${st2_hostname}"
echo "Using DataDog hostname: $my_hostname"
if [[ $my_hostname ]];
then
  docker run --rm -d --name dd-agent \
           --hostname "$my_hostname" \
           -v /var/run/docker.sock:/var/run/docker.sock:ro \
           -v /proc/:/host/proc/:ro \
           -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
           -v /mnt/stackstorm-data/datadog/conf.d:/conf.d/:ro \
           -v datadog-run-volume:/opt/datadog-agent/run:rw \
           -e DD_API_KEY=$dd_api_key \
           -e DD_LOGS_ENABLED=true \
           -e DD_PROCESS_AGENT_ENABLED=true \
           -e DD_HOSTNAME="$my_hostname" \
           datadog/agent:latest
fi

################################################################################
# start StackStorm
echo "Starting StackStorm"
# we want to persist the letsencrypt data, which is stored in ./data
# This can be controlled via an env var, which may not persist accross sessions:
#    export NGINX_FILES_PATH=/mnt/stackstorm-data/letsencrypt-data
# So we are manipulating the default location:
cd /opt/st2-docker-umccr
sudo rm -rf ./data
sudo ln -s /mnt/stackstorm-data/letsencrypt-data data
docker-compose up -d

################################################################################
# Redirect AMI cleaner logs to presistent location
echo "Setting up AMI cleaner log redirection"
sudo rm -f /opt/ami-cleaner/run.log
sudo ln -s /mnt/stackstorm-data/ami-cleaner.log /opt/ami-cleaner/run.log
