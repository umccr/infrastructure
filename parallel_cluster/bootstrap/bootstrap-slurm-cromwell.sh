#!/usr/bin/env bash

: '
Run through initial set up of node at launch time.
'

# Base level functions
echo_stderr() {
  echo "${@}" 1>&2
}

# Source config, tells us if we're on a compute or master node
. "/etc/parallelcluster/cfnconfig"

if [[ ! -v cfn_node_type ]]; then
  echo_stderr "cfn_node_type is not defined. Cannot determine if we're on a master or compute node. Exiting"
  exit 1
fi

# Exit on failed command
set -e

# Globals
# Globals - Miscell
# Which timezone are we in
TIMEZONE="Australia/Melbourne"
FSX_SCRATCH_DIR="/fsx/scratch2"

# Globals - slurm
# Slurm conf file we need to edit
SLURM_CONF_FILE="/opt/slurm/etc/slurm.conf"
SLURM_SINTERACTIVE_S3="s3://umccr-temp-dev/Alexis_parallel_cluster_test/slurm/scripts/sinteractive.sh"
SLURM_SINTERACTIVE_FILE_PATH="/opt/slurm/scripts/sinteractive"
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
CROMWELL_SLURM_CONFIG_FILE_PATH="/opt/cromwell/configs/slurm.conf"
CROMWELL_TOOLS_CONDA_ENV_NAME="cromwell_tools"
CROMWELL_WEBSERVICE_PORT=8000
CROMWELL_WORKDIR="${FSX_SCRATCH_DIR}/cromwell"
CROMWELL_TMPDIR="$(mktemp -d --suffix _cromwell)"
CROMWELL_LOG_LEVEL="DEBUG"
CROMWELL_LOG_MODE="pretty"
CROMWELL_MEM_MAX_HEAP_SIZE="4G"
CROMWELL_START_UP_HEAP_SIZE="1G"
CROMWELL_JAR_PATH="/opt/cromwell/jar/cromwell.jar"
CROMWELL_SERVER_PROC_ID=0

# Globals - BCBIO
BCBIO_CONDA_ENV_NAME="bcbio_nextgen_vm"

# Functions
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

  # Restart slurm control service with changes to conf file
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
  echo_stderr "Updating slurmdbd.conf"
  # We need to update the following attributes
  # DbdHost
  # StoragePass
  # StorageHost
  sed -i "/^DbdHost=/s/.*/DbdHost=\"$(hostname -s)\"/" "${SLURM_DBD_CONF_FILE_PATH}"
  sed -i "/^StoragePass=/s/.*/StoragePass=$(cat "${SLURM_DBD_PWD_FILE_PATH}")/" "${SLURM_DBD_CONF_FILE_PATH}"
  sed -i "/^StorageHost=/s/.*/StorageHost=$(cat "${SLURM_DBD_ENDPOINT_FILE_PATH}")/" "${SLURM_DBD_CONF_FILE_PATH}"

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
  { echo "JobAcctGatherType=jobacct_gather/linux"; \
    echo "JobAcctGatherFrequency=30"; \
    echo "AccountingStorageType=accounting_storage/slurmdbd"; \
    echo "AccountingStorageHost=$(hostname -s)"; \
    echo "AccountingStorageUser=admin"; \
    echo "AccountingStoragePort=6819"; \
    echo ""; } >> "${SLURM_CONF_FILE}"

  # Restart the slurm control service
  systemctl restart slurmctld

  # Start the slurmdb service
  /opt/slurm/sbin/slurmdbd
}

get_sinteractive_command() {
  # Ensure directory is available
  mkdir -p "$(dirname ${SLURM_SINTERACTIVE_FILE_PATH})"
  # Download sinteractive command
  aws s3 cp "${SLURM_SINTERACTIVE_S3}" "${SLURM_SINTERACTIVE_FILE_PATH}"
  # Add as executable
  chmod +x "${SLURM_SINTERACTIVE_FILE_PATH}"
  # Link to folder already in path
  ln -s "${SLURM_SINTERACTIVE_FILE_PATH}" "/usr/local/bin/sinteractive"
}

start_cromwell() {
  : '
  Start the cromwell service on launch of master node
  Placed logs under ~/cromwell-server.log for now
  '
  su - ec2-user \
    -c "
    nohup java \
    \"-Duser.timezone=${TIMEZONE}\" \
    \"-Duser.dir=${CROMWELL_WORKDIR}\" \
    \"-Dconfig.file=${CROMWELL_SLURM_CONFIG_FILE_PATH}\" \
    \"-Dwebservice.port=${CROMWELL_WEBSERVICE_PORT}\" \
    \"-Djava.io.tmpdir=${CROMWELL_TMPDIR}\" \
    \"-DLOG_LEVEL=${CROMWELL_LOG_LEVEL}\" \
    \"-DLOG_MODE=${CROMWELL_LOG_MODE}\" \
    \"-Xms${CROMWELL_START_UP_HEAP_SIZE}\" \
    \"-Xmx${CROMWELL_MEM_MAX_HEAP_SIZE}\" \
    \"-jar\" \"${CROMWELL_JAR_PATH}\" server > /home/ec2-user/cromwell-server.log 2>&1 &"
  CROMWELL_SERVER_PROC_ID="$!"
  logger "Starting cromwell under process ${CROMWELL_SERVER_PROC_ID}"
}


update_cromwell_env() {
  # Update conda and the environment on startup
  : '
  Create cromwell env to submit to cromwell server
  Add /opt/cromwell/scripts to PATH
  '
  # Create env for submitting workflows to cromwell
  su - ec2-user \
    -c "conda update --name \"${CROMWELL_TOOLS_CONDA_ENV_NAME}\" --all --yes"
}

update_bcbio_env() {
  # Update conda and the environment on startup
  : '
  Create cromwell env to submit to cromwell server
  Add /opt/cromwell/scripts to PATH
  '
  # Create env for submitting workflows to cromwell
  su - ec2-user \
    -c "conda update --name \"${BCBIO_CONDA_ENV_NAME}\" --all --yes"
}

update_base_conda_env(){
  # Update the base conda env
    # Create env for submitting workflows to cromwell
  su - ec2-user \
    -c "conda update --name \"base\" --all --yes"
}

# Complete slurm and cromwell post-slurm installation
case "${cfn_node_type}" in
    MasterServer)
      # Set mem attribute on slurm conf file
      echo_stderr "Enabling --mem parameter on slurm"
      enable_mem_on_slurm
      # Add sinteractive
      echo_stderr "Adding sinteractive command to /usr/local/bin"
      get_sinteractive_command
      # Connect slurm to rds
      echo_stderr "Connecting to slurm rds database"
      connect_sacct_to_mysql_db
      # Update base conda env
      echo_stderr "Updating base conda env"
      update_base_conda_env
      # Update bcbio conda env
      echo_stderr "Updating bcbio-env"
      update_bcbio_env
      # Update cromwell env
      echo_stderr "Update cromwell conda env for ec2-user"
      update_cromwell_env
      # Start cromwell service
      echo_stderr "Starting cromwell"
      start_cromwell
    ;;
    ComputeFleet)
    ;;
    *)
    ;;
esac