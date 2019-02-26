#!/bin/bash
set -eo pipefail

# TODO: parallelise (for example sync each fastq file separately?)

################################################################################
# Activate a conda environment where the required resources are available

. $HOME/.miniconda3/etc/profile.d/conda.sh
conda activate pipeline

script=$(basename "$0")
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function write_log {
  msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1"
  if test "$DEPLOY_ENV" = "prod"; then
    echo "$msg" >> "$DIR/${script}.log"
    echo "$msg" > /dev/udp/localhost/9999
  else
    echo "$msg" >> "$DIR/${script}.dev.log"
    echo "$msg"
  fi
}

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi
if test "$DEPLOY_ENV" = "dev"; then
  # Wait a bit to simulate work (and avoid tasks running too close to each other)
  sleep 5
fi

write_log "INFO: Invocation with parameters: $*"

if test "$#" -lt 10; then
  write_log "ERROR: Insufficient parameters"
  echo "A minimum of 4 arguments are required!"
  echo "  - The destination host [-d|--dest_host]"
  echo "  - The ssh user [-u|--ssh_user]"
  echo "  - The destination path [-p|--dest_path]"
  echo "  - The source paths [-s|--source_path]"
  echo "  - The runfolder name [-n|--runfolder-name]"
  echo "  - (optional) The rsync exclusions [-x|--exclude]"
  exit 1
fi

excludes=()
optional_args=()
while test "$#" -gt 0; do
  key="$1"

  case $key in
    -x|--exclude)
      excludes+=("$2")
      shift # past argument
      shift # past value
      ;;
    -d|--dest_host)
      dest_host="$2"
      shift # past argument
      shift # past value
      ;;
    -u|--ssh_user)
      ssh_user="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--dest_path)
      dest_path="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--source_path)
      source_path="$2"
      shift # past argument
      shift # past value
      ;;
    -n|--runfolder-name)
      runfolder_name="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option (everything else)
      optional_args+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

if test ! "$dest_host"; then
  write_log "ERROR: Parameter 'dest_host' missing"
  echo "You have to provide a dest_host parameter!"
  exit 1
fi

if test ! "$ssh_user"; then
  write_log "ERROR: Parameter 'ssh_user' missing"
  echo "You have to provide a ssh_user parameter!"
  exit 1
fi

if test ! "$dest_path"; then
  write_log "ERROR: Parameter 'dest_path' missing"
  echo "You have to provide a dest_path parameter!"
  exit 1
fi

if test ! "$source_path"; then
  write_log "ERROR: Parameter 'source_path' missing"
  echo "You have to provide a source_path parameter!"
  exit 1
fi

if [[ -z "$runfolder_name" ]]; then
  write_log "ERROR: Parameter 'runfolder_name' missing"
  echo "You have to define a runfolder name!"
  exit 1
fi

# TODO: just a sanity check
# TODO: could scrap runfolder_name parameter and extract name from source_path instead, as this is the current convention
# TODO: check that the runfolder dir exists or just let the conversion fail?
if [[ "$(basename $source_path)" != "$runfolder_name" ]]; then
  write_log "ERROR: The provided source directory does not match the provided runfolder name!"
  echo "ERROR: The provided runfolder directory does not match the provided runfolder name!"
  exit 1
fi

cmd="rsync -avh --chmod=o-rwx,g-w,Fg-x"
for i in "${excludes[@]}"; do
  cmd+=" --exclude $i"
done
cmd+=" $source_path -e \"ssh\" $ssh_user@$dest_host:$dest_path"


write_log "INFO: Running: $cmd"
if test "$DEPLOY_ENV" = "prod"; then
  eval "$cmd"
  exit_status="$?"
else
  echo "$cmd"
  exit_status="$?"
fi

if test "$exit_status" != "0"; then
  status="failure"
  error_msg="Error running rsync command. Exit status $exit_status"
  write_log "ERROR: $error_msg"
else
  status="success"
  write_log "INFO: sync command succeeded."
fi

write_log "INFO: All done."
