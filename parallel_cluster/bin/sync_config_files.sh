#!/usr/bin/env bash

ROOT_PATH="umccr-research-dev/parallel-cluster"

aws s3 sync "cromwell/" "s3://${ROOT_PATH}/cromwell/"
aws s3 sync "bootstrap/" "s3://${ROOT_PATH}/bootstrap/"
aws s3 sync "bcbio" "s3://${ROOT_PATH}/bcbio/"
aws s3 sync "slurm/scripts" "s3://${ROOT_PATH}/slurm/scripts"
aws s3 cp "slurm/conf/slurmdbd-template.conf" "s3://${ROOT_PATH}/slurm/conf/slurmdbd-template.conf"
# Upload password and end points
#aws s3 cp "slurm/conf/slurmdbd-endpoint.txt" "s3://${ROOT_PATH}/slurm/conf/slurmdbd-endpoint.txt"
#aws s3 cp "slurm/conf/slurmdbd-passwd.txt" "s3://${ROOT_PATH}/slurm/conf/slurmdbd-passwd.txt"