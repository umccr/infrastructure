#!/bin/bash
set -euxo pipefail

# A simple wrapper script around the actual umccrise command
# this is the actual command/script called by the Batch job

# NOTE: This script expects the following variables to be set on the environment
# - S3_INPUT_DIR      : The bcbio directory (S3 prefix) for which to run UMCCRise
# - S3_DATA_BUCKET    : The S3 bucket that holds the above data
# - S3_RESULT_BUCKET  : The S3 bucket that recieves the result data
# - S3_REFDATA_BUCKET : The S3 bucket for the reference data expected by UMCCRise
# - CONTAINER_VCPUS   : The number of vCPUs to assign to the container (for metric logging only)
# - CONTAINER_MEM     : The memory to assign to the container (for metric logging only)

# For backwards compatibility
if [ ! -n "${S3_RESULT_BUCKET+1}" ]; then
    S3_RESULT_BUCKET="$S3_DATA_BUCKET"
fi

# NOTE: this setup is NOT setup for multiple jobs per instance. With multiple jobs running in parallel
# on the same instance there could be issues related to shared volume/disk space, shared memeory space, etc

# TODO: could parallelise some of the setup steps?
#       i.e. download refdata and input in parallel

export AWS_DEFAULT_REGION="ap-southeast-2"
CLOUDWATCH_NAMESPACE="UMCCRISE"
CONTAINER_MOUNT_POINT="/work"
METADATA_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/instance-type/)
AMI_ID=$(curl -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/ami-id/)
UMCCRISE_VERSION=$(umccrise --version | sed 's/umccrise, version //') #get rid of unnecessary version text
REFDATA_DIR="/work/reference_data.git"
DVC_CACHE_DIR="/work/dvc/cache/"


function timer { # arg?: command + args
    start_time="$(date +%s)"
    $@
    end_time="$(date +%s)"
    duration="$(( $end_time - $start_time ))"
}

function publish { #arg 1: metric name, arg 2: value
    disk_space=$(df  | grep "${CONTAINER_MOUNT_POINT}$" | awk '{print $3}')

    # TODO: restructure metric, as is now only has one value (the duration) that can be graphed
    # TODO: ideally multiple metrics (duration, disc space, ...) are recorded for each job
    aws cloudwatch put-metric-data \
    --metric-name ${1} \
    --namespace $CLOUDWATCH_NAMESPACE \
    --unit Seconds \
    --value ${2} \
    --dimensions InstanceType=${INSTANCE_TYPE},AMIID=${AMI_ID},UMCCRISE_VERSION=${UMCCRISE_VERSION},S3_INPUT="${S3_DATA_BUCKET}/${S3_INPUT_DIR}",S3_REFDATA_BUCKET=${S3_REFDATA_BUCKET},CONTAINER_VCPUS=${CONTAINER_VCPUS},CONTAINER_MEM=${CONTAINER_MEM},DISK_SPACE=${disk_space}
}

sig_handler() {
    exit_status=$?  # Eg 130 for SIGINT, 128 + (2 == SIGINT)
    echo "Trapped signal $exit_status. Exiting."
    exit "$exit_status"
}
trap sig_handler INT HUP TERM QUIT EXIT

timestamp="$(date +%s)"

echo "Processing $S3_INPUT_DIR in bucket $S3_DATA_BUCKET with refdata from ${S3_REFDATA_BUCKET}"

avail_cpus="${1:-1}"
echo "Using  ${avail_cpus} CPUs."

# create a job specific output directory
job_output_dir=/work/output/${S3_INPUT_DIR}-${timestamp}

mkdir -p /work/{bcbio_project,${job_output_dir},panel_of_normals,pcgr,seq,tmp,validation}

# Install the AWS CLI
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -qq awscliv2.zip
./aws/install --install-dir "${HOME}/.local/" --bin-dir "${HOME}/.local/bin"

echo "PULL referenece data"
# clone the refData repo making sure we are not clashing with another process
while [ -d "$REFDATA_DIR" ]; do
  echo "Refdata dir already exists. Creating new one..."
  REFDATA_DIR="${REFDATA_DIR}_1"
done
git clone https://github.com/umccr/reference_data $REFDATA_DIR
cd $REFDATA_DIR

# use a common cache dir for all DVC repos/processes
mkdir -p $DVC_CACHE_DIR
dvc cache dir $DVC_CACHE_DIR
dvc config cache.type reflink,hardlink,symlink
timer dvc pull
cd /
publish S3PullRefGenome $duration

echo "PULL input (bcbio results) from S3 bucket"
timer aws s3 sync --only-show-errors --exclude=* --include=final/* --include=config/* s3://${S3_DATA_BUCKET}/${S3_INPUT_DIR} /work/bcbio_project/${S3_INPUT_DIR}/
publish S3PullInput $duration

echo "umccrise version:"
umccrise --version

echo "RUN umccrise"
timer umccrise /work/bcbio_project/${S3_INPUT_DIR} -j ${avail_cpus} -o ${job_output_dir} --genomes ${REFDATA_DIR}/genomes
publish RunUMCCRISE $duration

echo "PUSH results"
timer aws s3 sync --delete --only-show-errors ${job_output_dir} s3://${S3_RESULT_BUCKET}/${S3_INPUT_DIR}/umccrised
publish S3PushResults $duration

echo "Cleaning up..."
rm -rf "${job_output_dir}"

echo "All done."