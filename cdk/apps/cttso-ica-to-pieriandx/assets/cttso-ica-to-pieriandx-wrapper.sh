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

echo_stderr() {
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
          * PIERIANDX_BASE_URL
          * PIERIANDX_INSTITUTION
          * PIERIANDX_AWS_REGION
          * PIERIANDX_AWS_S3_PREFIX
          * PIERIANDX_USER_EMAIL

        Extras:
        The following values are taken from secrets manager:
        * ICA_ACCESS_TOKEN
        * PIERIANDX_AWS_S3_PREFIX
        * PIERIANDX_AWS_ACCESS_KEY_ID
        * PIERIANDX_USER_PASSWORD
        "

}

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

# Check env vars
if [[ -z "${ICA_BASE_URL-}" ]]; then
  echo_stderr "Could not find env var 'ICA_BASE_URL'"
  exit 1
fi
if [[ -z "${PIERIANDX_BASE_URL-}" ]]; then
  echo_stderr "Could not find env var 'PIERIANDX_BASE_URL'"
  exit 1
fi
if [[ -z "${PIERIANDX_INSTITUTION-}" ]]; then
  echo_stderr "Could not find env var 'PIERIANDX_INSTITUTION'"
  exit 1
fi
if [[ -z "${PIERIANDX_AWS_REGION-}" ]]; then
  echo_stderr "Could not find env var 'PIERIANDX_AWS_REGION'"
  exit 1
fi
if [[ -z "${PIERIANDX_AWS_S3_PREFIX-}" ]]; then
  echo_stderr "Could not find env var 'PIERIANDX_AWS_S3_PREFIX'"
  exit 1
fi
if [[ -z "${PIERIANDX_USER_EMAIL-}" ]]; then
  echo_stderr "Could not find env var 'PIERIANDX_USER_EMAIL'"
  exit 1
fi

# Create working directory and temp space
job_output_dir="$(mktemp \
  --directory \
  "${CONTAINER_MOUNT_POINT}/${sample_name}.workdir.XXX")"

# Create a job temp space
job_temp_space="$(mktemp \
  --directory \
  "${CONTAINER_MOUNT_POINT}/${sample_name}.tmpspace.XXX")"

# Set env vars
ICA_ACCESS_TOKEN="$(aws secretsmanager get-secret-value --secret-id 'IcaSecretsPortal' | \
                    jq --raw-output '.SecretString' \
                  )"
# FIXME - use nameless keys in future
PIERIANDX_AWS_ACCESS_KEY_ID="$(aws secretsmanager get-secret-value --secret-id 'PierianDx/AWSAccessKeyID' | \
                               jq --raw-output '.SecretString | fromjson | .PierianDxAWSAccessKeyID' \
                              )"
PIERIANDX_AWS_SECRET_ACCESS_KEY="$(aws secretsmanager get-secret-value --secret-id 'PierianDx/AWSSecretAccessKey' | \
                                   jq --raw-output '.SecretString | fromjson | .PierianDxAWSSecretAccessKey' \
                                 )"
PIERIANDX_USER_PASSWORD="$(aws secretsmanager get-secret-value --secret-id 'PierianDx/UserPassword' | \
                           jq --raw-output '.SecretString | fromjson | .PierianDxUserPassword' \
                          )"

# Export env vars
export ICA_ACCESS_TOKEN
export PIERIANDX_AWS_ACCESS_KEY_ID
export PIERIANDX_AWS_SECRET_ACCESS_KEY
export PIERIANDX_USER_PASSWORD

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