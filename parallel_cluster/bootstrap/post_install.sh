#!/usr/bin/env bash

: '
#################################################
INTRO
#################################################
Run through initial set up of node at launch time.
'

: '
#################################################
BASE LEVEL FUNCTIONS
#################################################
'
echo_stderr() {
  : '
  Writes output to stderr
  '

  echo "${@}" 1>&2
}

: '
#################################################
AWS FUNCTIONS
#################################################
'
this_instance_id() {
  : '
  Use the ec2-metadata command to return the instance id this ec2 instance is running on
  Assumes alinux2
  '

  local instance_id
  instance_id="$(ec2-metadata --instance-id | {
    # Returns instance-id: <instance_id>
    # So trim after the space
    cut -d' ' -f2
  })"
  # Return instance id
  echo "${instance_id}"
}

this_cloud_formation_stack_name() {
  : '
  Returns the cloud formation stack
  Single quotes over query command are intentional
  '
  local cloud_stack
  cloud_stack="$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=$(this_instance_id)" \
    --query='Reservations[*].Instances[*].Tags[?Key==`ClusterName`].Value[]' | {
    # Returns double nested like
    # [
    #  [
    #   "AlexisFSXTest"
    #  ]
    # ]
    jq --raw-output '.[0][0]'
  })"

  # Return cloud stack name
  echo "${cloud_stack}"
}

this_parallel_cluster_version() {
  : '
  Determines the version of parallel cluster
  Useful for ssm-parameters that are dependent on the parallel cluster version
  we are using
  '

  local pc_version
  pc_version="$(aws ec2 describe-instances \
                  --filters "Name=instance-id,Values=$(this_instance_id)" \
                  --query='Reservations[*].Instances[*].Tags[?Key==`ClusterName`].Value[]' | {
                  # Returns double nested like
                  # [
                  #  [
                  #   "2.9.0"
                  #  ]
                  # ]
                jq --raw-output '.[0][0]'
               })"

  # Returned pc-version
  echo "${pc_version}"

}

get_parallelcluster_filesystem_type() {
  : '
  Use this to choose if we need to set /efs or /fsx as our mount points
  '

  local file_system_types
  file_system_types="$(aws ec2 describe-instances \
    --filters "Name=instance-id,Values=$(this_instance_id)" \
    --query='Reservations[*].Instances[*].Tags[?Key==`aws-parallelcluster-filesystem`].Value[]' | {
    # Returns double nested like
    # [
    #  [
    #   "efs=0, multiebs=1, raid=0, fsx=1"
    #  ]
    # ]
    # Turn to
    # efs=0, multiebs=1, raid=0, fsx=1
    jq --raw-output '.[0][0]'
  } | {
    # efs=0, multiebs=1, raid=0, fsx=1
    # Turn To
    # efs=0
    # multiebs=1
    # raid=0
    # fsx=1
    sed 's%,\ %\n%g'
  } | {
    # Run while loop to see if efs=1 or fsx=1
    while read -r LINE; do
      if [[ "${LINE}" == "efs=1" ]]; then
        echo "efs"
        break
      elif [[ "${LINE}" == "fsx=1" ]]; then
        echo "fsx"
        break
      fi
    done
  })"

  # Return filesystem type
  echo "${file_system_types}"
}

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

get_rds_endpoint() {
  : '
  Take the RDS endpoint from inside an SSM parameter
  '
  local rds_endpoint
  rds_endpoint="$(aws ssm get-parameter --name "${SLURM_DBD_SSM_KEY_ENDPOINT}" | {
                  jq --raw-output '.Parameter.Value'
                })"
  echo "${rds_endpoint}"
}

get_rds_passwd() {
  : '
  Take the RDS parameter SecureString, decrypt and return the value
  '
  local rds_passwd
  rds_passwd="$(aws ssm get-parameter --name "${SLURM_DBD_SSM_KEY_PASSWD}" --with-decryption | {
    jq --raw-output '.Parameter.Value'
  })"
  echo "${rds_passwd}"
}

: '
#################################################
SLURM FUNCTIONS
#################################################
'
is_slurmdb_up() {
  : '
  Checks if slurmdb is talking to storage port
  1 for up, 0 otherwise
  '
  local slurmdb_status
  local storage_port=6819
  slurmdb_status=$(netstat -antp | {
    grep LISTEN
  } | {
    grep -c "${storage_port}"
  })
  echo "${slurmdb_status}"
}

is_cluster() {
  : '
  Checks if this cloud stack has already been registered as a cluster
  1 for yes, 0 otherwise
  '
  local has_cluster
  local stack_name_lower_case="$1"

  has_cluster="$(/opt/slurm/bin/sacctmgr list cluster \
    format=Cluster \
    --parsable2 \
    --noheader | {
    grep -c "^${stack_name_lower_case}$"
  })"
  echo "${has_cluster}"
}

wait_for_slurm_db() {
  : '
  Wait for port 6819 to start running before proceeding
  '
  local counter=0
  local max_retries=10
  while [[ "$(is_slurmdb_up)" == "0" ]]; do
    # Wait another five seconds before trying again
    sleep 5
    # Check we're not stuck in an infinite loop
    if [[ "${counter}" -gt "${max_retries}" ]]; then
      echo_stderr "Timeout on connecting to slurm database - exiting"
      exit 1
    fi
    # Increment tries by one
    counter=$((counter + 1))
  done
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
  include_cluster_line_num=$(grep -n "${SLURM_CONF_INCLUDE_CLUSTER_LINE}" "${SLURM_CONF_FILE}" | {
                             cut -d':' -f1
                            })
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

  # Stop the slurm control service daemon while we fix a few thigns
  systemctl stop slurmctld

  # Download conf files
  echo_stderr "Downloading necessary files for slurm dbd conf"
  aws s3 cp "${SLURM_DBD_CONF_FILE_S3}" \
    "${SLURM_DBD_CONF_FILE_PATH}"

  # Update slurmdbd.conf
  echo_stderr "Updating slurmdbd.conf"
  # We need to update the following attributes
  # DbdHost
  # StoragePass
  # StorageHost
  sed -i "/^DbdHost=/s/.*/DbdHost=\"$(hostname -s)\"/" "${SLURM_DBD_CONF_FILE_PATH}"
  sed -i "/^StoragePass=/s/.*/StoragePass=$(get_rds_passwd)/" "${SLURM_DBD_CONF_FILE_PATH}"
  sed -i "/^StorageHost=/s/.*/StorageHost=$(get_rds_endpoint)/" "${SLURM_DBD_CONF_FILE_PATH}"

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
  {
    echo "JobAcctGatherType=jobacct_gather/linux"
    echo "JobAcctGatherFrequency=30"
    echo "AccountingStorageType=accounting_storage/slurmdbd"
    echo "AccountingStorageHost=$(hostname -s)"
    echo "AccountingStorageUser=admin"
    echo "AccountingStoragePort=6819"
    echo ""
  } >>"${SLURM_CONF_FILE}"

  # Get lower case version of the cluster name
  local stack_name_lower_case
  stack_name_lower_case="$(this_cloud_formation_stack_name | {
                           tr '[:upper:]' '[:lower:]'
                          })"

  # Rename the slurm cluster to the name of the CFN instance (As there can only be one of these running at once)
  sed -i "/^ClusterName=/s/.*/ClusterName=${stack_name_lower_case}/" "${SLURM_CONF_FILE}"

  # Start the slurmdb service daemon
  echo_stderr "Starting slurm daemon"
  /opt/slurm/sbin/slurmdbd

  # Delete the state check (just in case it's started running, will prevent us from restarting otherwise)
  rm -f /var/spool/slurm.state/clustername

  # Start the slurm control service daemon
  echo_stderr "Starting slurm control daemon"
  systemctl start slurmctld

  # Wait for the slurm manager to start talking before proceeding
  echo_stderr "Wait for slurmdb to start up before checking if we need to create a new cluster"
  wait_for_slurm_db

  # Attach to existing cluster
  # TODO how to change to starting job number so we can kick off where we started
  # Don't override existing jobs for this cluster?
  # 0 if does NOT contain the cluster, 1 if does
  echo_stderr "Checking the cluster list"
  if [[ "$(is_cluster "${stack_name_lower_case}")" == "0" ]]; then
    # Add the cluster
    echo_stderr "Registering ${stack_name_lower_case} as a cluster"
    # Override prompt with 'yes'
    # Write to /dev/null incase of a SIGPIEP signal
    yes 2>/dev/null | /opt/slurm/bin/sacctmgr add cluster "${stack_name_lower_case}"
  fi

  # Restart the slurm control service daemon
  echo_stderr "Restarting slurm cluster"
  systemctl restart slurmctld
}

modify_slurm_port_range() {
  : '
  Necessary only for AWS PC 2.9.1
  Seems to get the wrong port range 6817-6827
  We change this to 6820 to 6830
  Stops 6818 and 6819, used for slurmdb connections
  being interfered with
  '
  sed -i 's/SlurmctldPort=6817-6827/SlurmctldPort=6820-6830/' "${SLURM_CONF_FILE}"
}

get_sinteractive_command() {
  # Ensure directory is available
  mkdir -p "$(dirname "${SLURM_SINTERACTIVE_FILE_PATH}")"
  # Download sinteractive command
  aws s3 cp "${SLURM_SINTERACTIVE_S3}" "${SLURM_SINTERACTIVE_FILE_PATH}"
  # Add as executable
  chmod +x "${SLURM_SINTERACTIVE_FILE_PATH}"
  # Link to folder already in path
  ln -s "${SLURM_SINTERACTIVE_FILE_PATH}" "/usr/local/bin/sinteractive"
}

: '
#################################################
USER SETUP FUNCTIONS
#################################################
'
create_start_cromwell_script() {
  : '
  Start the cromwell service on launch of master node
  Placed logs under ~/cromwell-server.log for now
  '

  # Set path
  script_dir="$(dirname "${CROMWELL_SERVER_START_SCRIPT_PATH}")"

  # Make tmpdir writable - use sticky bit
  chmod 1777 "${CROMWELL_TMPDIR}"

  # Create bin directory
  su - ec2-user \
    -c "mkdir -p \"${script_dir}\""

  # Create a bash script for the user to run cromwell
  {
    echo -e "nohup java \\"
    echo -e "\t-Duser.timezone=\"${TIMEZONE}\" \\"
    echo -e "\t-Duser.dir=\"${CROMWELL_WORKDIR}\" \\"
    echo -e "\t-Dconfig.file=\"${CROMWELL_SLURM_CONFIG_FILE_PATH}\" \\"
    echo -e "\t-Dwebservice.port=\"${CROMWELL_WEBSERVICE_PORT}\" \\"
    echo -e "\t-Djava.io.tmpdir=\"${CROMWELL_TMPDIR}\" \\"
    echo -e "\t-DLOG_LEVEL=\"${CROMWELL_LOG_LEVEL}\" \\"
    echo -e "\t-DLOG_MODE=\"${CROMWELL_LOG_MODE}\" \\"
    echo -e "\t-Xms\"${CROMWELL_START_UP_HEAP_SIZE}\" \\"
    echo -e "\t-Xmx\"${CROMWELL_MEM_MAX_HEAP_SIZE}\" \\"
    echo -e "\t-jar \"${CROMWELL_JAR_PATH}\" \\"
    echo -e "\t\tserver > \"/home/ec2-user/cromwell-server.log\" 2>&1 &"
  } > "${CROMWELL_SERVER_START_SCRIPT_PATH}"

  # Change executable permissions
  chmod +x "${CROMWELL_SERVER_START_SCRIPT_PATH}"

  # Change owner to ec2-user
  chown ec2-user:ec2-user "${CROMWELL_SERVER_START_SCRIPT_PATH}"
}

: '
#################################################
CONDA UPDATE FUNCTIONS
#################################################
'
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
  : '
  Update conda and the environment on startup
  '
  # Create env for submitting workflows to cromwell
  su - ec2-user \
    -c "conda update --name \"${BCBIO_CONDA_ENV_NAME}\" --all --yes"
}

update_toil_env() {
  : '
  Update the toil environment on startup
  '
  su - ec2-user \
    -c "conda update --name \"${TOIL_CONDA_ENV_NAME}\" --all --yes; \
        conda activate \"${TOIL_CONDA_ENV_NAME}\"; \
        pip install --upgrade \"toil[all]\""
  # FIXME --net=none when launching docker containers
  # Could be a NetworkAccess Requirement?
  su - ec2-user \
    -c "conda activate \"${TOIL_CONDA_ENV_NAME}\"; \
        sed -i 's/net=none/net=host/g' \"\${CONDA_PREFIX}/lib/python3.8/site-packages/cwltool/docker.py\""
}

update_base_conda_env() {
  # Update the base conda env
  # Create env for submitting workflows to cromwell
  su - ec2-user \
    -c "conda update --name \"base\" --all --yes"
}

write_shared_dir_to_bashrc() {
  : '
  Get SHARED_FILESYSTEM_MOUNT and write to ~/.bashrc
  '
  su - ec2-user \
    -c "echo export SHARED_DIR=\\\"${SHARED_FILESYSTEM_MOUNT}\\\" >> /home/ec2-user/.bashrc"
}

clean_conda_envs() {
  : '
  Clean all conda envs
  '
  su - ec2-user \
    -c "conda clean --all --yes"
}

: '
#################################################
GLOBALS
#################################################
'

# Globals
S3_BUCKET_DIR_SSM_KEY="/parallel_cluster/dev/s3_config_root"

# Globals - Miscell
# Which timezone are we in
TIMEZONE="Australia/Melbourne"
# Use get_parallelcluster_filesystem_type command to determine
# filesystem mount point
# /fsx if the filesystem is fsx
# /efs if the filesystem is efs
filesystem_type="$(get_parallelcluster_filesystem_type)"
if [[ "${filesystem_type}" == "fsx" ]]; then
  SHARED_FILESYSTEM_MOUNT="/fsx"
elif [[ "${filesystem_type}" == "efs" ]]; then
  SHARED_FILESYSTEM_MOUNT="/efs"
else
  # Set /efs as default
  echo_stderr "Warning, couldn't find the type of filesystem we're on"
  echo_stderr "Setting as /efs by default"
  SHARED_FILESYSTEM_MOUNT="/efs"
fi

# Globals - slurm
# Slurm conf file we need to edit
SLURM_CONF_FILE="/opt/slurm/etc/slurm.conf"
SLURM_SINTERACTIVE_S3="$(get_pc_s3_root)/slurm/scripts/sinteractive.sh"
SLURM_SINTERACTIVE_FILE_PATH="/opt/slurm/scripts/sinteractive"
# Total mem on a m5.4xlarge parition is 64Gb
# This value MUST be lower than the RealMemory attribute from `/opt/slurm/sbin/slurmd -C`
# Otherwise slurm will put the nodes into 'drain' mode.
# When run on a compute node - generally get around 63200 - subtract 2 Gb to be safe.
SLURM_COMPUTE_NODE_REAL_MEM="62000"
# If just CR_CPU, then slurm will only look at CPU
# To determine if a node is full.
SLURM_SELECT_TYPE_PARAMETERS="CR_CPU_Memory"
SLURM_DEF_MEM_PER_CPU="4000" # Memory (MB) available per CPU
# Line we wish to insert
SLURM_CONF_REAL_MEM_LINE="NodeName=DEFAULT RealMemory=${SLURM_COMPUTE_NODE_REAL_MEM}"
# Line we wish to place our snippet above
if [[ "$(this_parallel_cluster_version)" == "2.8.1" ]]; then
  SLURM_CONF_INCLUDE_CLUSTER_LINE="include slurm_parallelcluster_nodes.conf"
elif [[ "$(this_parallel_cluster_version)" == "2.9.0" ]]; then
  SLURM_CONF_INCLUDE_CLUSTER_LINE="include slurm_parallelcluster.conf"
else
  SLURM_CONF_INCLUDE_CLUSTER_LINE="include slurm_parallelcluster.conf"
fi
# Our template slurmdbd.conf to download
# Little to no modification from the example shown here:
# https://aws.amazon.com/blogs/compute/enabling-job-accounting-for-hpc-with-aws-parallelcluster-and-amazon-rds/
SLURM_DBD_CONF_FILE_S3="$(get_pc_s3_root)/slurm/conf/slurmdbd-template.conf"
SLURM_DBD_CONF_FILE_PATH="/opt/slurm/etc/slurmdbd.conf"
# S3 Password
SLURM_DBD_SSM_KEY_PASSWD="/parallel_cluster/dev/slurm_rds_db_password"
# RDS Endpoint
SLURM_DBD_SSM_KEY_ENDPOINT="/parallel_cluster/dev/slurm_rds_endpoint"

# Globals - Cromwell
CROMWELL_SLURM_CONFIG_FILE_PATH="/opt/cromwell/configs/slurm.conf"
CROMWELL_TOOLS_CONDA_ENV_NAME="cromwell_tools"
CROMWELL_WEBSERVICE_PORT=8000
# Remove from options.json file
CROMWELL_WORKDIR="${SHARED_FILESYSTEM_MOUNT}/cromwell"
CROMWELL_TMPDIR="$(mktemp -d --suffix _cromwell)"
CROMWELL_LOG_LEVEL="INFO"
CROMWELL_LOG_MODE="pretty"
CROMWELL_MEM_MAX_HEAP_SIZE="4G"
CROMWELL_START_UP_HEAP_SIZE="1G"
CROMWELL_JAR_PATH="/opt/cromwell/jar/cromwell.jar"
CROMWELL_SERVER_START_SCRIPT_PATH="/home/ec2-user/bin/start-cromwell-server.sh"

# Globals - bcbio
BCBIO_CONDA_ENV_NAME="bcbio_nextgen_vm"

# Globals - Toil
TOIL_CONDA_ENV_NAME="toil"

: '
#################################################
START
#################################################
'

# Exit on failed command
set -e

# Source config, tells us if we're on a compute or master node
. "/etc/parallelcluster/cfnconfig"

# Check cfn_node_type is defined
if [[ ! -v cfn_node_type ]]; then
  echo_stderr "cfn_node_type is not defined. Cannot determine if we're on a master or compute node. Exiting"
  exit 1
fi

# Complete slurm and cromwell post-slurm installation
case "${cfn_node_type}" in
    MasterServer)
      # Set mem attribute on slurm conf file
      echo_stderr "Enabling --mem parameter on slurm"
      enable_mem_on_slurm
      # Add sinteractive
      echo_stderr "Adding sinteractive command to /usr/local/bin"
      get_sinteractive_command
      # Modify Slurm Port Range
      echo_stderr "Modifying slurm port range - done before trying connect to slurm database"
      modify_slurm_port_range
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
      # Update toil env
      echo_stderr "Update the toil env for ec2-user"
      update_toil_env
      # Start cromwell service
      echo_stderr "Creating start cromwell script"
      create_start_cromwell_script
      # Write SHARED_DIR env var to bashrc
      echo_stderr "Setting SHARED_DIR for user"
      write_shared_dir_to_bashrc
      # Clean conda env
      echo_stderr "Cleaning conda envs"
      clean_conda_envs

    ;;
    ComputeFleet)
      # Do nothing
    ;;
    *)
      # Do nothing
    ;;
esac
