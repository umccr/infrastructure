#!/bin/bash
set -eo pipefail

# define constants, like default folders, etc
fastq_data_base_path="/storage/shared/bcl2fastq_output"
qc_output_base_path="/storage/shared/dev/multiQC"

# check input arguments
runfolder=$1
# runfolder format check
if [[ $runfolder =~ ^[0-9]{6}_A00130_[0-9]{4}_.{10}$ ]]; then
    echo "Runfolder matches expected pattern"
else
    echo "Runfolder does not match expected pattern!"
    exit 1
fi

# generate path variables
stats_folder_base_path="$fastq_data_base_path/$runfolder/"
stats_folders="${stats_folder_base_path}Stats_custom.*"

# translate list of host stats path into equivalent list of container paths
fldr_list=""
shopt -s nullglob
for stats_folder in $stats_folders; do
    fldr=`basename "$stats_folder"`
    fldr_list+="/$runfolder/$fldr "
done
shopt -u nullglob

cmd="docker run --rm --user 1002 -v $fastq_data_base_path/$runfolder/:/$runfolder/:ro -v $qc_output_base_path/:/output/ umccr/multiqc multiqc -f -m bcl2fastq $fldr_list -o /output/${runfolder}/ -n ${runfolder}_bcl2fastq_qc.html --title \"UMCCR MultiQC report (bcl2fastq) for $runfolder\""
echo "$cmd"
eval "$cmd"

echo "All done."