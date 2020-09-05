#!/usr/bin/env bash

# Globals
ROOT_PATH="umccr-research-dev/parallel-cluster"

# AMI components
aws s3 sync "ami/" "s3://${ROOT_PATH}/ami/"

# Pre and Post install scripts
aws s3 sync "bootstrap/" "s3://${ROOT_PATH}/bootstrap/"

# Slurm templates and scripts
aws s3 sync "slurm/" "s3://${ROOT_PATH}/slurm/"

# Cromwell templates and scripts (with conda env)
aws s3 sync "cromwell/" "s3://${ROOT_PATH}/cromwell/"

# Bcbio config (and conda env)
aws s3 sync "bcbio/" "s3://${ROOT_PATH}/bcbio/"

# Toil (just conda env at this point)
aws s3 sync "toil/" "s3://${ROOT_PATH}/toil/"
