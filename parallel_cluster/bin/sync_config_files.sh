#!/usr/bin/env bash

ROOT_PATH="umccr-temp-dev/Alexis_parallel_cluster_test"

aws s3 sync "cromwell/" "s3://${ROOT_PATH}/cromwell/"
aws s3 sync "bootstrap/" "s3://${ROOT_PATH}/bootstrap/"
aws s3 sync "bcbio" "s3://${ROOT_PATH}/bcbio/"
aws s3 sync "slurm/scripts" "s3://${ROOT_PATH}/slurm/scripts"