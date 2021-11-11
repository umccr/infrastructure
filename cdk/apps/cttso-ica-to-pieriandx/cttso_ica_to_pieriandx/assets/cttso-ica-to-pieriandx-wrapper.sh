#!/usr/bin/env bash

# Set to fail
set -euo pipefail

: '
A simple wrapper script around the actual cttso-ica-to-pieriandx command
this is the actual command/script called by the Batch job

NOTE: This script expects the following variables to be set on the environment
CONTAINER_VCPUS   : The number of vCPUs to assign to the container (for metric logging only)
CONTAINER_MEM     : The memory to assign to the container (for metric logging only)
'

export AWS_DEFAULT_REGION="ap-southeast-2"
CLOUDWATCH_NAMESPACE="cttso-ica-to-pieriandx"
CONTAINER_MOUNT_POINT="/work"
METADATA_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/instance-type/)
AMI_ID=$(curl -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" -v http://169.254.169.254/latest/meta-data/ami-id/)

function echo_stderr() {
  : '
  Write output to stderr
  '
  echo "$@" 1>&2
}

# Help function
print_help(){
  echo "
        Usage: cttso-ica-to-pieriandx-wrapper.sh (--ica-workflow-run-id wfr....)
                                                 (--accession-json-str {'accession_name': ...})
                                                 (--sample-name SBJ0000_L21000000)

        Description:
          Run cttso-ica-to-pieriandx through docker

        Options:
            --ica-workflow-run-id:             Required: The ica workflow run id for a given sample
            --accession-json-base64-str:       Required: The accession information json as a base64 string
            --sample-name:                     Required: The name of the sample (used to create the tempdir)

        Requirements:
          * docker

        Environment:
          * ICA_BASE_URL
          * ICA_ACCESS_TOKEN
          * PIERIANDX_BASE_URL
          * PIERIANDX_INSTITUTION
          * PIERIANDX_AWS_REGION
          * PIERIANDX_AWS_S3_PREFIX
          * PIERIANDX_AWS_ACCESS_KEY_ID
          * PIERIANDX_AWS_SECRET_ACCESS_KEY
          * PIERIANDX_USER_EMAIL
          * PIERIANDX_USER_PASSWORD
        "
}

# Check docker is present
if ! type docker 1>/dev/null 2>&1; then
  echo_stderr "Could not find the docker binary in PATH: ${PATH}. Please ensure docker is installed on this instance first"
  exit 1
fi

# Set inputs as defaults
ica_workflow_run_id=""
accession_json_base64_str=""
sample_name=""

# Get args from command line
while [ $# -gt 0 ]; do
  case "$1" in
    --ica-workflow-run-id)
      ica_workflow_run_id="$2"
      shift 1
      ;;
    --accession-json-base64-str)
      accession_json_base64_str="$2"
      shift 1
      ;;
    --sample-name)
      sample_name="$2"
      shift 1
      ;;
    -h | --help)
      print_help
      exit 0
      ;;
  esac
  shift 1
done

# Create working directory and temp space
job_output_dir="$(mktemp \
  --tmpdir /work \
  --directory \
  -t "${sample_name}.workdir.XXX")"

# Create a job temp space
job_temp_space="$(mktemp \
  --tmpdir /work \
  --directory \
  -t "${sample_name}.tmpspace.XXX")"

# Run the workflow
(
  # Change to working directory for this job
  cd "${job_output_dir}"

  # Set temp directory to allocated space
  export TMPDIR="${job_temp_space}"

  # Create the accession json file
  accession_json="$(mktemp -t "${sample_name}.accession-json.XXX")"

  # Convert base64 to the accession json and write to tmp file
  echo "${accession_json_base64_str}" | \
    base64 --decode | \
    jq --raw-output > "${accession_json}"

  # Run the python script
  cttso-ica-to-pieriandx.py \
    --ica-workflow-run-ids "${ica_workflow_run_id}" \
    --accession-json "${accession_json}"
)

echo_stderr "Cleaning up..."
rm -rf "${job_output_dir}" "${job_temp_space}"

echo_stderr "All done."