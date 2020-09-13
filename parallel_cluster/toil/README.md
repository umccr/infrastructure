# Getting started with toil

## Start an interactive session
> This ensures that a compute node is constantly running.
>
```bash
sinteractive
```

## Create directories
> Create the following directories in your shared filesystem mount (probably /efs)

```bash
SHARED_FILESYSTEM_DIR="/efs"
TOIL_JOB_STORE="${SHARED_FILESYSTEM_DIR}/toil/job-store"
TOIL_WORKDIR="${SHARED_FILESYSTEM_DIR}/toil/workdir"
TOIL_TMPDIR="${SHARED_FILESYSTEM_DIR}/toil/tmpdir"
TOIL_LOG_DIR="${SHARED_FILESYSTEM_DIR}/toil/logs"
TOIL_OUTPUTS="${SHARED_FILESYSTEM_DIR}/toil/outputs"
```

```bash
mkdir -p "${TOIL_JOB_STORE}"
mkdir -p "${TOIL_WORKDIR}"
mkdir -p "${TOIL_TMPDIR}"
mkdir -p "${TOIL_LOG_DIR}"
mkdir -p "${TOIL_OUTPUTS}"
```

## Running TOIL

```bash
srun \
  --output "logs/toil.%j.%s.log" \
  --error "logs/toil.%j.%s.log" \
  bash -c "\
    toil-cwl-runner \
      --jobStore \"${TOIL_JOB_STORE}/\${SLURM_JOB_ID}.\${SLURM_STEP_ID}.log\" \
      --workDir \"${TOIL_WORKDIR}\" \
      --outdir \"${TOIL_OUTPUTS}\" \
      --writeLogs \"${TOIL_LOG_DIR}\" \
      --batchSystem slurm \
      --cleanWorkDir=onSuccess \
      \"my-cwl-tool.packed.json\" \
      \"my-cwl-tool.packed.input.json\""
```

## Where are all my files

Before traversing the many files inside `TOIL_JOB_STORE` or `TOIL_WORKDIR`, it may be of consideration to
look at `logs/toil.*.*.log` which will print the command that has failed.  
If you think this command is correct and you need to debug further, I would recommend tinkering the `--cleanWorkDir`
parameter of the command above. I've changed this from `always` to `onSuccess` meaning all failed jobs will be 
able to investigated

## Why is the job file in binary format.

This is a great question. If you would like to look at the job file you can use some python magic 
to look deeper into these job files

```python
from pprint import pprint
import pickle
with open("/path/to/binary/job", "rb") as pickle_h:
  job_obj = pickle.load(pickle_h)
pprint(job_obj)
```

If you have a look at the `job_obj` attribute 'command' this should lead you to a 'stream' object.
You may use the same method above to import the stream file which may assist you further in your debugging.

## Rerunning a workflow
I would recommend ensuring that no docker containers are continuing to run in the backgroud before a workflow 
is resubmitted. This appears to be a slurm bug not killing process IDs of subprocesses when scancel is invoked

## Troubleshooting

### Java Host Exception error.

You may need to run this line, to enable the docker host to access some host metadata
Action: Alexis to file bug with toil, likely using a cwltool version containing [this bug](https://github.com/common-workflow-language/cwltool/issues/1139)

This has been incorporated into the post_install.sh script for your convenience.

```
sed -i 's/net=none/net=host/g' "${CONDA_PREFIX}/lib/python3.8/site-packages/cwltool/docker.py"
```

### Job doesn't appear to be running
> I have resubmitted my job and it has been launched on a node, but nothing appears to be happening

Unsure what the root cause is here, but it's likely that the previous cleanup didn't finish.  
This is probably an AWS Parallel Cluster implementation issue where slurm doesn't cancel the commands
that have been executed under a job id.

Therefore to solve this issue, I would recommend prior to restarting to shell into your compute nodes and run
`docker container list`. And see if there are any hanging docker containers - they will appear as running,
use the timestamp to see if they actually reflect a current job run. If not, use `docker container kill` to remove them.
This should allow your resubmitted job to start running.

### My job seems have launched two jobs for the one task

This has been filed under [this toil bug](https://github.com/DataBiosphere/toil/issues/3189).
Other than temporarily wasting computing resources, this bug will not affect your workflow.