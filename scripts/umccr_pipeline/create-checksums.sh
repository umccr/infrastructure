#!/bin/bash
set -eo pipefail

# TODO: change hard coded exclude paths into parameters
# TODO: make more generic
# TODO: parallelise
# TODO: create .md5 file per input file

################################################################################
# Activate a conda environment where the required resources are available

. $HOME/.miniconda3/etc/profile.d/conda.sh
conda activate pipeline

################################################################################
# Constants/Variables

HASHFUNC="md5sum"
#HASHFUNC="xxh64sum"
THREADS=5

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
    echo "$msg"
  fi
}


################################################################################
# Actual start of script

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi
if test "$DEPLOY_ENV" = "dev"; then
  # Wait a bit to simulate work (and avoid tasks running too close to each other)
  sleep 5
fi

write_log "INFO: Invocation with parameters: $*"

use_case="$1"
directory="$2"
runfolder_name="$3"


if test "$directory" && test -d "$directory"
then
  write_log "INFO: Moving to $directory"
  cd "$directory"
else
  write_log "ERROR: Not a valid directory: $directory"
  (>&2 echo "ERROR: Not a valid directory: $directory")
  exit 1
fi



if test "$use_case" = 'bcl2fastq'; then
  cmd="find . -not \( -path ./bcl2fastq.$HASHFUNC -prune \) -type f | parallel -j $THREADS $HASHFUNC > ./bcl2fastq.$HASHFUNC"
  write_log "INFO: Running: $cmd"
  if test "$DEPLOY_ENV" = "prod"; then
    eval "$cmd"
    exit_status="$?"
  else
    echo "$cmd"
    exit_status="$?"
  fi
elif test "$use_case" = 'runfolder'; then
  cmd="find . -not \( -path ./Thumbnail_Images -prune \) -not \( -path ./Data -prune \) -not \( -path ./runfolder.$HASHFUNC -prune \) -type f | parallel -j $THREADS $HASHFUNC > ./runfolder.$HASHFUNC"
  write_log "INFO: Running: $cmd"
  if test "$DEPLOY_ENV" = "prod"; then
    eval "$cmd"
    exit_status="$?"
  else
    write_log "DEBUG: [dev]: $cmd"
    exit_status="$?"
  fi
else
  write_log "ERROR: Not a valid use case: $use_case"
  (>&2 echo "ERROR: Not a valid use case: $use_case")
  echo " Usage: ./$script [bcl2fastq|runfolder] <directory path>"
  exit 1
fi

if test "$exit_status" != "0"; then
  status="failure"
  error_msg="Checksum creation failed with exit status $exit_status"
else
  status="success"
fi

write_log "INFO: All done."
