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
instance_id=`cat /var/lib/cloud/data/instance-id`
echo "Instance ID: $instance_id"
echo "Allocation ID: ${allocation_id}"
# NOTE: allocation_id is an external variable filled by Terraform when rendering the script
aws ec2 associate-address --instance-id $instance_id --allocation-id ${allocation_id}

# TODO: the host name is hard coded to `prod`, but should be dependent on the AWS account we are deploying to
# start the DataDog agent
docker run --rm -d --name dd-agent \
           --hostname umccr-stackstorm-prod \
           -v /var/run/docker.sock:/var/run/docker.sock:ro \
           -v /proc/:/host/proc/:ro \
           -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
           -v /mnt/stackstorm-data/datadog/conf.d:/conf.d/:ro \
           -v datadog-run-volume:/opt/datadog-agent/run:rw \
           -e DD_API_KEY=e0dcb38a11a21b9315c12d594e7772f1 \
           -e DD_LOGS_ENABLED=true \
           -e DD_HOSTNAME=umccr-stackstorm-dd \
           datadog/agent:latest

# start StackStorm
/opt/st2-docker-umccr/docker-compose-up.sh
