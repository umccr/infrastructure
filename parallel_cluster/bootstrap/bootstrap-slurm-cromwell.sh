#!/bin/bash

. "/etc/parallelcluster/cfnconfig"

# Exit on failed command
set -e

# Globals
# Globals - Miscell
# Which timezone are we in
TIMEZONE="Australia/Melbourne"
FSX_DIR="/fsx"

# Globals - slurm
# Slurm conf file we need to edit
SLURM_CONF_FILE="/opt/slurm/etc/slurm.conf"
# Total mem on a m5.4xlarge parition is 64Gb
# This value MUST be lower than the RealMemory attribute from `/opt/slurm/sbin/slurmd -C`
# Otherwise slurm will put the nodes into 'drain' mode.
# When run on a compute node - generally get around 63200 - subtract 2 Gb to be safe.
SLURM_COMPUTE_NODE_REAL_MEM="62000"
# If just CR_CPU, then slurm will only look at CPU
# To determine if a node is full.
SLURM_SELECT_TYPE_PARAMETERS="CR_CPU_Memory"
SLURM_DEF_MEM_PER_CPU="4000"  # Memory (MB) available per CPU
# Line we wish to insert
SLURM_CONF_REAL_MEM_LINE="NodeName=DEFAULT RealMemory=${SLURM_COMPUTE_NODE_REAL_MEM}"
# Line we wish to place our snippet above
SLURM_CONF_INCLUDE_CLUSTER_LINE="include slurm_parallelcluster_nodes.conf"
# Our template slurmdbd.conf to download
# Little to no modification from the example shown here:
# https://aws.amazon.com/blogs/compute/enabling-job-accounting-for-hpc-with-aws-parallelcluster-and-amazon-rds/
SLURM_DBD_CONF_FILE_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/slurm/conf/slurmdbd-template.conf"
SLURM_DBD_CONF_FILE_PATH="/opt/slurm/etc/slurmdbd.conf"
# S3 Password
SLURM_DBD_PWD_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/slurm/conf/slurmdbd-passwd.txt"
SLURM_DBD_PWD_FILE_PATH="/root/slurmdbd-pwd.txt"
# RDS Endpoint
SLURM_DBD_ENDPOINT_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/slurm/conf/slurmdbd-endpoint.txt"
SLURM_DBD_ENDPOINT_FILE_PATH="/root/slurmdbd-endpoint.txt"

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
CROMWELL_WORKDIR="/fsx/cromwell"
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
  sed -i "${include_cluster_line_num}i${SLURM_CONF_REAL_MEM_LINE}" "${SLURM_CONF_FILE}"

  # Replace SelectTypeParameters default (CR_CPU) with (CR_CPU_MEMORY)
  sed -i "/^SelectTypeParameters=/s/.*/SelectTypeParameters=${SLURM_SELECT_TYPE_PARAMETERS}/" "${SLURM_CONF_FILE}"

  # Add DefMemPerCpu to cluster line (final line of the config)
  sed -i "/^PartitionName=/ s/$/ DefMemPerCPU=${SLURM_DEF_MEM_PER_CPU}/" "${SLURM_CONF_FILE}"

  # Restart slurm database with changes to conf file
  systemctl restart slurmctld
}


connect_sacct_to_mysql_db() {
  : '
  Programmatically adds the slurm accounting db to the cluster.
  Adds the slurmdb.conf file to /opt/slurm/etc
  Updates the slurmdb.conf and slurm.conf with the necessary username and password.
  '

  # Download conf files
  echo_stderr "Downloading necessary files for slurm dbd conf"
  aws s3 cp "${SLURM_DBD_CONF_FILE_S3}" \
    "${SLURM_DBD_CONF_FILE_PATH}"
  aws s3 cp "${SLURM_DBD_PWD_S3}" \
    "${SLURM_DBD_PWD_FILE_PATH}"
  aws s3 cp "${SLURM_DBD_ENDPOINT_S3}" \
    "${SLURM_DBD_ENDPOINT_FILE_PATH}"

  # Update slurmdbd.conf
  # We need to update the following attributes
  # DbdHost
  # StoragePass
  # StorageHost
  sed -i "/^DbdHost=/s/.*/DbdHost=$(cat "${SLURM_DBD_ENDPOINT_FILE_PATH}")/" "${SLURM_DBD_CONF_FILE_PATH}"
  sed -i "/^StoragePass=/s/.*/StoragePass=$(cat "${SLURM_DBD_PWD_FILE_PATH}")/" "${SLURM_DBD_CONF_FILE_PATH}"
  sed -i "/^StorageHost=/s/.*/StorageHost=$(hostname -s)/" "${SLURM_DBD_CONF_FILE_PATH}"

  # Delete password and endpoint files under /root
  rm -f "${SLURM_DBD_ENDPOINT_FILE_PATH}" "${SLURM_DBD_PWD_FILE_PATH}"

  # Update slurm.conf
  echo_stderr "Updating slurm.conf"
  # We need to update the following attributes
  # JobAcctGatherType=jobacct_gather/linux
  # JobAcctGatherFrequency=30
  # #
  # AccountingStorageType=accounting_storage/slurmdbd
  # AccountingStorageHost=`hostname -s`
  # AccountingStorageUser=admin
  # AccountingStoragePort=6819
  # These are all commented out by default in the standard slurm file
  # Search for the commented out and add in.
  sed -i "/^\#JobAcctGatherType=/s/.*/JobAcctGatherType=jobacct_gather/linux/" "${SLURM_CONF_FILE}"
  sed -i "/^\#JobAcctGatherFrequency=/s/.*/JobAcctGatherFrequency=30" "${SLURM_CONF_FILE}"
  sed -i "/^\#AccountingStorageType=/s/.*/AccountingStorageType=accounting_storage/slurmdbd/" "${SLURM_CONF_FILE}"
  sed -i "/^\#AccountingStorageHost=/s/.*/AccountingStorageHost=$(hostname -s)/" "${SLURM_CONF_FILE}"
  sed -i "/^\#AccountingStorageUser=/s/.*/AccountingStorageUser=admin/" "${SLURM_CONF_FILE}"
  sed -i "/^\#AccountingStoragePort=/s/.*/AccountingStoragePort=6819/" "${SLURM_CONF_FILE}"

  # Restart the slurm database
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
  Placed logs under ~/cromwell-server.log for now
  '
  su - ec2-user \
    -c "
    nohup java \
    "-Duser.timezone=${TIMEZONE}" \
    "-Duser.dir=${CROMWELL_WORKDIR}" \
    "-Dconfig.file=${CROMWELL_SLURM_CONFIG_FILE_PATH}" \
    "-Dwebservice.port=${CROMWELL_WEBSERVICE_PORT}" \
    "-Djava.io.tmpdir=${CROMWELL_TMPDIR}" \
    "-DLOG_LEVEL=${CROMWELL_LOG_LEVEL}" \
    "-DLOG_MODE=${CROMWELL_LOG_MODE}" \
    "-Xms${CROMWELL_START_UP_HEAP_SIZE}" \
    "-Xmx${CROMWELL_MEM_MAX_HEAP_SIZE}" \
    -jar "${CROMWELL_JAR_PATH}" server >/home/ec2-user/cromwell-server.log 2>&1 &"
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
        cp \"${CROMWELL_TOOLS_CONDA_ENV_FILE_PATH}\" ./; \
        conda env create \
          --file \$(basename \"${CROMWELL_TOOLS_CONDA_ENV_FILE_PATH}\") \
          --name \"${CROMWELL_TOOLS_CONDA_ENV_NAME}\""

  # Add script path to env_vars.sh
  su - ec2-user \
    -c "conda activate \"${CROMWELL_TOOLS_CONDA_ENV_NAME}\" && \
        mkdir -p \"\${CONDA_PREFIX}/etc/conda/activate.d/\" && \
        echo \"export PATH=\\\"${CROMWELL_SCRIPTS_DIR}:\\\$PATH\"\\\" >> \
        \"\${CONDA_PREFIX}/etc/conda/activate.d/env_vars.sh\""
}

change_fsx_permissions() {
  : '
  Change fsx permissions s.t entire directory is owned by the ec2-user
  '
  chown ec2-user:ec2-user "${FSX_DIR}"
}

# Processes to complete on ALL (master and compute) nodes at startup
# Security updates
yum update -y
# Set timezone to Australia/Melbourne
timedatectl set-timezone "${TIMEZONE}"
# Start the docker service
systemctl start docker
# Add ec2-user to docker group
usermod -a -G docker ec2-user

case "${cfn_node_type}" in
    MasterServer)
      # FIXME delete this once new ami has these installed
      yum install -y -q \
        mysql
      # Set mem attribute on slurm conf file
      echo_stderr "Enabling --mem parameter on slurm"
      enable_mem_on_slurm
      # Connect slurm to rds
      connect_sacct_to_mysql_db
      # Get necessary files from S3 to start cromwell
      echo_stderr "Getting necessary files from cromwell"
      get_cromwell_files
      # Start cromwell service
      echo_stderr "Starting cromwell"
      start_cromwell
      # Create cromwell env to enable submitting to service from user
      echo_stderr "Creating cromwell conda env for ec2-user"
      create_cromwell_env
      # Set /fsx to ec2-user
      change_fsx_permissions
    ;;
    ComputeFleet)
    ;;
    *)
    ;;
esac