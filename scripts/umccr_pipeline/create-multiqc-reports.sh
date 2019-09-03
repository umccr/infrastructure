#!/bin/bash
set -eo pipefail

################################################################################
# Constants

CASE_BCL2FASTQ="bcl2fastq"
CASE_INTEROP="interop"
fastq_data_base_path="/storage/shared/bcl2fastq_output"
bcl_data_base_path="/storage/shared/raw/Baymax"
qc_output_base_path="/storage/shared/dev/multiQC"

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


# check input arguments
use_case=$1
if test "$use_case" != "$CASE_BCL2FASTQ" && test "$use_case" != "$CASE_INTEROP"; then
    write_log "ERROR: Unsupported use case $use_case. Supported are: $CASE_BCL2FASTQ and $CASE_INTEROP."
    exit 1
fi
runfolder=$2
# runfolder format check
if [[ ! $runfolder =~ ^[0-9]{6}_A00130_[0-9]{4}_.{10}$ ]]; then
    write_log "ERROR: Runfolder does not match expected pattern!"
    exit 1
fi

if test "$use_case" == "$CASE_BCL2FASTQ"; then
    write_log "INFO: Generating report for $CASE_BCL2FASTQ"
    # construct the base directory and make sure it exists
    bcl2fastq_stats_base_path="$fastq_data_base_path/$runfolder"
    if test ! -d "$bcl2fastq_stats_base_path"
    then
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

    cmd="docker run --rm --user 1002 -v $fastq_data_base_path/$runfolder/:/$runfolder/:ro -v $qc_output_base_path/:/output/ umccr/multiqc multiqc -f -m bcl2fastq $fldr_list -o /output/${runfolder}/ -n ${runfolder}_bcl2fastq_qc.html --title \"UMCCR MultiQC report (bcl2fastq) for $runfolder\""
    write_log "INFO: Running command: $cmd"
    if test "$DEPLOY_ENV" = "prod"; then
        eval "$cmd"
    fi
fi


if test "$use_case" == "$CASE_INTEROP"; then
    write_log "INFO: Generating report for $CASE_INTEROP"
    # construct the base directory and make sure it exists
    interop_base_path="$bcl_data_base_path/$runfolder"
    if test ! -d "$interop_base_path"
    then
        write_log "ERROR: Directory does not exist: $interop_base_path"
        exit 1
    fi


    cmd="docker run --rm --user 1002 -v $interop_base_path/:/$runfolder/:ro -v $qc_output_base_path/:/output/ umccr/multiqc bash -c 'interop_index-summary --csv=1 /${runfolder}/ > /tmp/interop_index-summary.csv; interop_summary --csv=1 /${runfolder}/ > /tmp/interop_summary.csv; multiqc -m interop /tmp/interop*.csv -o /output/${runfolder}/ -n ${runfolder}_interop_qc.html --title \"UMCCR MultiQC report (interop) for $runfolder\"'"
    write_log "INFO: Running command: $cmd"
    if test "$DEPLOY_ENV" = "prod"; then
        eval "$cmd"
    fi
fi


write_log "INFO: All done."



# interop_index-summary --csv=1 190621_A00130_0108_AHLHYHDSXX/ > interop_index-summary.csv
# interop_summary --csv=1 190621_A00130_0108_AHLHYHDSXX/ > interop_summary.csv
# multiqc -m interop *.csv -o interop_multiqc

# docker run --rm --user 1002 -v /storage/shared/raw/Baymax/190510_A00130_0103_BHKKVWDSXX/:/190510_A00130_0103_BHKKVWDSXX/:ro -v /storage/shared/dev/multiQC/:/output/ umccr/multiqc interop_index-summary --csv=1 /190510_A00130_0103_BHKKVWDSXX/ > /tmp/interop_index-summary.csv && interop_summary --csv=1 /190510_A00130_0103_BHKKVWDSXX/ > /tmp/interop_summary.csv && multiqc -m interop /tmp/interop*.csv -o /output/interop_multiqc
# docker run --rm --user 1002 -v /storage/shared/raw/Baymax/190510_A00130_0103_BHKKVWDSXX/:/190510_A00130_0103_BHKKVWDSXX/:ro -v /storage/shared/dev/multiQC/:/output/ umccr/multiqc bash -c "interop_index-summary --csv=1 /190510_A00130_0103_BHKKVWDSXX/ > /tmp/interop_index-summary.csv; interop_summary --csv=1 /190510_A00130_0103_BHKKVWDSXX/ > /tmp/interop_summary.csv; multiqc -m interop /tmp/interop*.csv -o /output/190510_A00130_0103_BHKKVWDSXX/ -n 190510_A00130_0103_BHKKVWDSXX_interop_qc.html"