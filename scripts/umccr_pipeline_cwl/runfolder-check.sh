#!/bin/bash
set -eo pipefail

################################################################################
# Initial checks on the runfolder to assertain that the run is complete and was successfui.
# This should prevent downstream tasks to fail due to obvious issues with the runfolder

##########
# Checks
# - check that the following flag files are present
flag_files=( "SequenceComplete.txt" "RTAComplete.txt" "CopyComplete.txt")

script_name=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi
# No difference between dev and prod except for the logging output file

################################################################################
# Define functions

function write_log {
  msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script_name: $1"
  echo "$msg"
  if test "$DEPLOY_ENV" = "prod"; then
    echo "$msg"
  else
    echo "$msg"
  fi
}

################################################################################
# Main script logic


write_log "INFO: Invocation with parameters: $*"

if test "$#" -ne 1; then
  write_log "ERROR: The runfolder path to check is not given!"
  write_log "Please provide the runfolder path as single argument."
  exit 1
fi

runfolder_path="$1"

for flag_file in "${flag_files[@]}"; do
  if [ ! -f "$runfolder_path/$flag_file" ]; then
    write_log "ERROR: $flag_file not found!"
    exit 1
  fi
done
