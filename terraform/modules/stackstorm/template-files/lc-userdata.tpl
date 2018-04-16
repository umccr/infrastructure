#!/bin/bash


################################################################################
# mount the stackstorm configuration volume and docker volume onto the instance
echo "Creating mount points"
mkdir "/mnt/stackstorm-data"
mkdir "/mnt/stackstorm-docker"

# TODO: find better way to get the actual device name
echo "/dev/xvdf  /mnt/stackstorm-data ext4  defaults,nofail  0  2" >> /etc/fstab
echo "/dev/xvdg  /mnt/stackstorm-docker ext4  defaults,nofail  0  2" >> /etc/fstab
mount -a

################################################################################
# associate our elastic IP with the instance
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`cat /var/lib/cloud/data/instance-id`
echo "Instance ID: $instance_id"
echo "Allocation ID: ${allocation_id}"
# NOTE: allocation_id is an external variable filled by Terraform when rendering the script
aws ec2 associate-address --instance-id $instance_id --allocation-id ${allocation_id}


################################################################################
# TODO: the host name is hard coded to `prod`, but should be dependent on the AWS account we are deploying to
# start the DataDog agent
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
           -e DD_API_KEY=e0dcb38a11a21b9315c12d594e7772f1 \
           -e DD_LOGS_ENABLED=true \
           -e DD_PROCESS_AGENT_ENABLED=true \
           -e DD_HOSTNAME="$my_hostname" \
           datadog/agent:latest
fi

################################################################################
# start StackStorm
/opt/st2-docker-umccr/docker-compose-up.sh
