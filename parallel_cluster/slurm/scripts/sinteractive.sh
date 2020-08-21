#!/usr/bin/env bash

check_nodes(){
  # Check a node is ready
  node_length=$(scontrol show nodes --oneliner | grep -v "DRAIN" | grep -cv "No nodes in the system")
  echo "${node_length}"
}

if [[ "$(check_nodes)" == "0" ]]; then
  sbatch --wait --wrap "sleep 2" >/dev/null 2>&1
fi

# tcsh implementation adds -l param
if [[ ! "${SHELL}" == "/bin/tcsh" ]]; then
  eval srun "$*" --pty -u "${SHELL}" -i -l
else
  eval srun "$*" --pty -u "${SHELL}" -i
fi
