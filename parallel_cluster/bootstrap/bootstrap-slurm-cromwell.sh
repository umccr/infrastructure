#!/bin/bash

. "/etc/parallelcluster/cfnconfig"

# Exit on failed command
set -e

# Globals
# Globals - Miscell
# Which timezone are we in
TIMEZONE="Australia/Melbourne"
# Globals - slurm
# Total mem on a m5.4xlarge parition is 64Gb
# This value MUST be lower than the RealMemory attribute from `/opt/slurm/sbin/slurmd -C`
# Otherwise slurm will put the nodes into 'drain' mode.
# When run on a compute node - generally get around 63200 - subtract 2 Gb to be safe.
SLURM_COMPUTE_NODE_REAL_MEM="62000"
# Slurm conf file we need to edit
SLURM_CONF_FILE="/opt/slurm/etc/slurm.conf"
# Line we wish to insert
SLURM_CONF_REAL_MEM_LINE="NodeName=DEFAULT RealMemory=${SLURM_COMPUTE_NODE_REAL_MEM}"
# Line we wish to place our snippet above
SLURM_CONF_INCLUDE_CLUSTER_LINE="include slurm_parallelcluster_nodes.conf"
# Globals - Cromwell
CROMWELL_SLURM_CONFIG_FILE_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/cromwell/configs/slurm.conf"
CROMWELL_SLURM_CONFIG_FILE_PATH="/opt/cromwell/configs/slurm.conf"
CROMWELL_OPTIONS_CONFIG_FILE_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/cromwell/configs/options.json"
CROMWELL_OPTIONS_CONFIG_FILE_PATH="/opt/cromwell/configs/options.json"
CROMWELL_TOOLS_CONDA_ENV_FILE_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/cromwell/env/cromwell_conda_env.yml"
CROMWELL_TOOLS_CONDA_ENV_FILE_PATH="/opt/cromwell/env/cromwell_tools.yml"
CROMWELL_TOOLS_CONDA_ENV_NAME="cromwell_tools"
CROMWELL_SCRIPTS_DIR="/opt/cromwell/scripts"
CROMWELL_TOOLS_SUBMIT_WORKFLOW_SCRIPT_FILE_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/cromwell/scripts/submit_to_cromwell.py"
CROMWELL_TOOLS_SUBMIT_WORKFLOW_SCRIPT_FILE_PATH="${CROMWELL_SCRIPTS_DIR}/submit_workflow_to_cromwell.py"
CROMWELL_SBATCH_SUBMIT_FILE_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/cromwell/scripts/submit_to_sbatch.sh"
CROMWELL_SBATCH_SUBMIT_FILE_PATH="${CROMWELL_SCRIPTS_DIR}/submit_to_sbatch.sh"
CROMWELL_WEBSERVICE_PORT=8000
CROMWELL_WORKDIR="/scratch/cromwell"
CROMWELL_TMPDIR="$(mktemp -d --suffix _cromwell)"
CROMWELL_LOG_LEVEL="DEBUG"
CROMWELL_LOG_MODE="pretty"
CROMWELL_MEM_MAX_HEAP_SIZE="4G"
CROMWELL_START_UP_HEAP_SIZE="1G"
CROMWELL_JAR_PATH="/opt/cromwell/jar/cromwell.jar"
CROMWELL_SERVER_PROC_ID=0

echo_stderr() {
  echo "${@}" 1>&2
}

enable_mem_on_slurm() {
  : '
    # Update slurm conf to expect memory capacity of ComputeFleet based on input
    # Should be 64 Gbs of real memory for a m5.4xlarge partition
    # However we lose around 800mb on average with overhead.
    # Take off 2GB to be safe
    # Workaround taken from https://github.com/aws/aws-parallelcluster/issues/1517#issuecomment-561775124
  '
  # Get line of INCLUDE_CLUSTER_LINE
  local include_cluster_line_num
  include_cluster_line_num=$(grep -n "${SLURM_CONF_INCLUDE_CLUSTER_LINE}" "${SLURM_CONF_FILE}" | cut -d':' -f1)
  # Prepend with REAL_MEM_LINE
  sed -i "${include_cluster_line_num}i${SLURM_CONF_REAL_MEM_LINE}" /opt/slurm/etc/slurm.conf
  # Restart slurm database with changes to conf file
  systemctl restart slurmctld
}

get_cromwell_files() {
  : '
  Pull necessary cromwell files from s3
  '
  aws s3 cp "${CROMWELL_SLURM_CONFIG_FILE_S3}" \
    "${CROMWELL_SLURM_CONFIG_FILE_PATH}"
  aws s3 cp "${CROMWELL_OPTIONS_CONFIG_FILE_S3}" \
    "${CROMWELL_OPTIONS_CONFIG_FILE_PATH}"
  aws s3 cp "${CROMWELL_TOOLS_CONDA_ENV_FILE_S3}" \
    "${CROMWELL_TOOLS_CONDA_ENV_FILE_PATH}"
  aws s3 cp "${CROMWELL_TOOLS_SUBMIT_WORKFLOW_SCRIPT_FILE_S3}" \
    "${CROMWELL_TOOLS_SUBMIT_WORKFLOW_SCRIPT_FILE_PATH}"
  aws s3 cp "${CROMWELL_SBATCH_SUBMIT_FILE_S3}" \
    "${CROMWELL_SBATCH_SUBMIT_FILE_PATH}"
}

start_cromwell() {
  : '
  Start the cromwell service on launch of master node
  '
  java \
    "-Duser.timezone=${TIMEZONE}" \
    "-Duser.dir=${CROMWELL_WORKDIR}" \
    "-Dconfig.file=${CROMWELL_SLURM_CONFIG_FILE_PATH}" \
    "-Dwebservice.port=${CROMWELL_WEBSERVICE_PORT}" \
    "-Djava.io.tmpdir=${CROMWELL_TMPDIR}" \
    "-DLOG_LEVEL=${CROMWELL_LOG_LEVEL}" \
    "-DLOG_MODE=${CROMWELL_LOG_MODE}" \
    "-Xms${CROMWELL_START_UP_HEAP_SIZE}" \
    "-Xmx${CROMWELL_MEM_MAX_HEAP_SIZE}" \
    -jar "${CROMWELL_JAR_PATH}" server 1>/dev/null &
  CROMWELL_SERVER_PROC_ID="$!"
  logger "Starting cromwell under process ${CROMWELL_SERVER_PROC_ID}"
}

create_cromwell_env() {
  : '
  Create cromwell env to submit to cromwell server
  Add /opt/cromwell/scripts to PATH
  '
  # Create env for submitting workflows to cromwell
  su - ec2-user \
    -c "cd \$(mktemp -d); \
        cp \"${CROMWELL_TOOLS_CONDA_FILE_PATH}\" ./; \
        conda env create \
          --file \$(basename \"${CROMWELL_TOOLS_CONDA_FILE_PATH}\") \
          --name \"${CROMWELL_TOOLS_CONDA_ENV_NAME}\""

  # Add script path to env_vars.sh
  su - ec2-user \
    -c "conda activate \"${CROMWELL_TOOLS_CONDA_ENV_NAME}\" && \
        mkdir -p \"\${CONDA_PREFIX}/etc/conda/activate.d/\" && \
        echo \"export PATH=\\\"${CROMWELL_SCRIPTS_DIR}:\\\$PATH\"\\\" >> \
        \"\${CONDA_PREFIX}/etc/conda/activate.d/env_vars.sh\""
}

# Processes to complete on ALL (master and compute) nodes at startup
# Security updates
yum update -y
# Set timezone to Australia/Melbourne
timedatectl set-timezone "${TIMEZONE}"
# Start the docker service
systemctl start docker

case "${cfn_node_type}" in
    MasterServer)
      # Set mem attribute on slurm conf file
      echo_stderr "Enabling --mem parameter on slurm"
      enable_mem_on_slurm
      # Get necessary files from S3 to start cromwell
      echo_stderr "Getting necessary files from cromwell"
      get_cromwell_files
      # Start cromwell service
      echo_stderr "Starting cromwell"
      start_cromwell
      # Create cromwell env to enable submitting to service from user
      echo_stderr "Creating cromwell conda env for ec2-user"
      create_cromwell_env
    ;;
    ComputeFleet)
    ;;
    *)
    ;;
esac