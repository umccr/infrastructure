#!/bin/bash

################################################################################
# start the DataDog agent
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
           -e DD_API_KEY=${var.dd-agent.api_key} \
           -e DD_LOGS_ENABLED=true \
           -e DD_PROCESS_AGENT_ENABLED=true \
           -e DD_HOSTNAME="$my_hostname" \
           datadog/agent:latest
fi