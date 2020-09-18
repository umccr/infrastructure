#!/bin/bash
set -eo pipefail

################################################################################
# Constants

docker_image="umccr/multiqc:1.2.2"
CASE_BCL2FASTQ="bcl2fastq"
CASE_INTEROP="interop"
rundata_s3_path="s3://umccr-run-data-prod/QC-Reports"
fastq_base_path="/storage/shared/bcl2fastq_output"
bcl_base_path="/storage/shared/raw"
qc_base_path="/storage/shared/multiQC"
qc_report_path="$qc_base_path/Reports"
qc_data_path="$qc_base_path/Data"
qc_fastq_source_path="$qc_base_path/Data"
qc_bcl_source_path="$qc_base_path/Data"

runfolder_regex='([12][0-9][01][0-9][0123][0-9])_(A01052|A00130)_([0-9]{4})_[A-Z0-9]{10}'

script=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

################################################################################
# Functions

function write_log {
    msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1"
    if test "$DEPLOY_ENV" = "prod"; then
        echo "$msg" >> $DIR/${script}.log
    else
        echo "$msg" >> $DIR/${script}.dev.log
    fi
    echo "$msg"
}

function backup_qc_source_data {
    run_id=$1
    # Get instrument ID from run ID and chose correct base path
    # NOTE: no quotes around the regex!!
    if [[ "$run_id" =~ $runfolder_regex ]]; then
        instrument_id="${BASH_REMATCH[2]}"
        write_log "DEBUG: Extracted instrument ID: $instrument_id"
    else
        write_log "ERROR: Runfolder did not match expected format!"
        exit 2
    fi

    if [[ "$instrument_id" == "A01052" ]]; then
        source_dir=${bcl_base_path}/Po/${run_id}
    elif [[ "$instrument_id" == "A00130" ]]; then
        source_dir=${bcl_base_path}/Baymax/${run_id}
    else
        write_log "ERROR: Unknown instrument"
        exit 2
    fi

    write_log "INFO: Using runfolder base path: $source_dir"
    if test -e $source_dir; then
        cmd="rsync -ah $source_dir ${qc_data_path} --exclude Thumbnail_Images --exclude Data --exclude Recipe --exclude Logs --exclude Config --exclude *Complete.txt"
        write_log "INFO: running command: $cmd"
        eval "$cmd"
    else
        write_log "INFO: Source data directory ($source_dir) does not exist. Assuming data is already present."
    fi

    source_dir=${fastq_base_path}/${run_id}
    if test -e $source_dir; then
        cmd="rsync -ah ${fastq_base_path}/${run_id}/Stats_custom.* ${qc_data_path}/${run_id}/"
        write_log "INFO: running command: $cmd"
        eval "$cmd"
        cmd="rsync -ah ${fastq_base_path}/${run_id}/Reports_custom.* ${qc_data_path}/${run_id}/"
        write_log "INFO: running command: $cmd"
        eval "$cmd"
    else
        write_log "INFO: Source data directory ($source_dir) does not exist. Assuming data is already present."
    fi
}


################################################################################
# Actual start of script

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi
if test "$DEPLOY_ENV" = "dev"; then
    # Wait a bit to simulate work (and avoid pipeline tasks running too close to each other)
    sleep 5
fi

write_log "INFO: Invocation with parameters: $*"


runfolder=$1
# runfolder format check
# NOTE: no quotes around the regex!!
if [[ ! "$runfolder" =~ $runfolder_regex ]]; then
    write_log "ERROR: Runfolder does not match expected pattern!"
    exit 1
fi

# Backup data for QC reports
backup_qc_source_data "$runfolder"


if test "$DEPLOY_ENV" = "prod"; then
    # Create QC report from bcl2fastq output
    write_log "INFO: Generating report for $CASE_BCL2FASTQ"
    # construct the base directory and make sure it exists
    bcl2fastq_stats_base_path="$qc_fastq_source_path/$runfolder"
    if test ! -d "$bcl2fastq_stats_base_path"; then
        write_log "ERROR: Directory does not exist: $bcl2fastq_stats_base_path"
        exit 1
    fi

    # translate list of host stats path into equivalent list of container paths
    stats_folders="${bcl2fastq_stats_base_path}/Stats_custom.*"
    fldr_list=""
    shopt -s nullglob
    for stats_folder in $stats_folders; do
        fldr=`basename "$stats_folder"`
        fldr_list+="/$runfolder/$fldr "
    done
    shopt -u nullglob

    cmd="docker run --rm --user 1002 -v $bcl2fastq_stats_base_path/:/$runfolder/:ro -v $qc_report_path/:/output/ $docker_image multiqc -f -m bcl2fastq $fldr_list -o /output/${runfolder}/ -n ${runfolder}_bcl2fastq_qc.html --title \"UMCCR MultiQC report (bcl2fastq) for $runfolder\""
    write_log "INFO: Running command: $cmd"
    eval "$cmd"

    # Create QC reports from raw data
    write_log "INFO: Generating report for $CASE_INTEROP"
    # construct the base directory and make sure it exists
    interop_base_path="$qc_bcl_source_path/$runfolder"
    if test ! -d "$interop_base_path"; then
        write_log "ERROR: Directory does not exist: $interop_base_path"
        exit 1
    fi

    # Run the docker container to generate the reports
    cmd="docker run --rm --user 1002 -v $interop_base_path/:/$runfolder/:ro -v $qc_report_path/:/output/ $docker_image bash -c 'interop_index-summary --csv=1 /${runfolder}/ > /tmp/interop_index-summary.csv; interop_summary --csv=1 /${runfolder}/ > /tmp/interop_summary.csv; multiqc -f -m interop /tmp/interop*.csv -o /output/${runfolder}/ -n ${runfolder}_interop_qc.html --title \"UMCCR MultiQC report (interop) for $runfolder\"'"
    write_log "INFO: Running command: $cmd"
    eval "$cmd"

    # Copy MultiQC report data to S3
    cmd="aws s3 sync $qc_base_path/Reports/${runfolder}/ ${rundata_s3_path}/${runfolder}"
    write_log "INFO: running command: $cmd"
    eval "$cmd"

else
    write_log "INFO: Test run, skipping actual work"
fi

write_log "INFO: All done."
