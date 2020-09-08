#!/usr/bin/env bash

# Functions
get_pc_s3_root() {
  : '
  Get the s3 root for the cluster files
  '
  local s3_cluster_root
  s3_cluster_root="$(aws ssm get-parameter --name "${S3_BUCKET_DIR_SSM_KEY}" | {
                     jq --raw-output '.Parameter.Value'
                   })"
  echo "${s3_cluster_root}"
}

# Globals
S3_BUCKET_DIR_SSM_KEY="/parallel_cluster/dev/s3_config_root"

# AMI components
aws s3 sync "ami/" "$(get_pc_s3_root)/ami/"

# Pre and Post install scripts
aws s3 sync "bootstrap/" "$(get_pc_s3_root)/bootstrap/"

# Slurm templates and scripts
aws s3 sync "slurm/" "$(get_pc_s3_root)/slurm/"

# Cromwell templates and scripts (with conda env)
aws s3 sync "cromwell/" "$(get_pc_s3_root)/cromwell/"

# Bcbio config (and conda env)
aws s3 sync "bcbio/" "$(get_pc_s3_root)/bcbio/"

# Toil (just conda env at this point)
aws s3 sync "toil/" "$(get_pc_s3_root)/toil/"
