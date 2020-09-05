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
TOIL_JOB_STORE="${SHARED_FILESYSTEM_DIR}/toil/job-store.%j"
TOIL_WORKDIR="${SHARED_FILESYSTEM_DIR}/toil/workdir"
TOIL_TMPDIR="${SHARED_FILESYSTEM_DIR}/toil/tmpdir"
TOIL_LOG_DIR="${SHARED_FILESYSTEM_DIR}/toil/logs"
TOIL_OUTPUTS="${SHARED_FILESYSTEM_DIR}/toil/outputs"
```

```bash
mkdir -p "${TOIL_WORKDIR}"
mkdir -p "${TOIL_TMPDIR}"
mkdir -p "${TOIL_LOG_DIR}"
mkdir -p "${TOIL_OUTPUTS}"
```

## Running TOIL

```bash
srun 
  --output "logs/toil.%j.%s.log" \
  --error "logs/toil.%j.%s.log" \
  toil-cwl-runner \
    --jobStore "${TOIL_JOB_STORE}.%s.log" \
    --workDir "${TOIL_WORKDIR}" \
    --outdir "${TOIL_OUTPUTS}" \
    --writeLogs "${TOIL_LOG_DIR}" \
    --batchSystem slurm \
    my-cwl-tool.packed.json \
    my-cwl-tool.packed.input.json
```

## Troubleshooting

### Java Host Exception error.

You may need to run this line, to enable the docker host to access some host metadata
Action: Alexis to file bug with toil, likely using a cwltool version containing [this bug](https://github.com/common-workflow-language/cwltool/issues/1139)

This has been incorporated into the post_install.sh script for your convenience.

```
sed -i 's/net=none/net=host/g' "${CONDA_PREFIX}/lib/python3.8/site-packages/cwltool/docker.py"
```



