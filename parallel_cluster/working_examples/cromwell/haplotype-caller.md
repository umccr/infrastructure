## Haplotype caller 

**An AWS parallel cluster walkthrough**

## Overview

### Contents
This is a straight forward example of running a WDL through parallel cluster.  
The following code will:

1. Set up a parallel cluster through cloud formation.
2. Start the cromwell server on the master node
3. Download the reference data and input data through sbatch commands.
   * These jobs are run on compute nodes. 
   * You will need to make sure they complete
     before running the wdl script
4. Download and configure the input-json for the WDL workflow
5. Submit the wdl job to the cromwell server.
6. Patiently wait for the job to finish.
7. Upload the data to your preferred S3 bucket.

### Sources:

The following resources are courtesy of the Broad Institute. 

### Further reading

* [Cromwell Docs](https://cromwell.readthedocs.io/en/stable/)
* [WDL Repo](https://github.com/openwdl/wdl)
* [Slurm Docs](https://slurm.schedmd.com/sbatch.html)

## Starting the cluster

The cluster uses the `umccr_dev` template.  
This command is launched from the umccr/infrastructure repo under the `parallel_cluster` directory. 

Assumes sso login has been completed and pcluster conda env is activated.

### Command from local machine

```bash
./bin/start_cluster.sh --cluster-template umccr_dev ${USER}WDLHaplotypeCaller`

# Log in with
ssm i-XXXX
```

### Running through screen

By running through screen, we are able to pop in-and-out of this workflow
without losing our environment variables that we collect along the way

```bash
screen -S "haplotype_caller_workflow"
```

## Setup and Data Staging

### Declare shared directory

This should be in your `~/.bashrc` profile.

```bash
if [[ ! -v SHARED_DIR ]]; then
  SHARED_DIR="/efs"  ## /fsx if the umccr_dev_fsx cluster template was used
fi
```

### Start Cromwell server

```bash
bash "${HOME}/bin/start-cromwell-server.sh"
```

The server is now running on port 8000

### Create the logs directory

```bash
LOG_DIR="${HOME}/logs"
mkdir -p "${LOG_DIR}"
```

### Create gsutil env
> Will put this in the conda env post install list at some point.

For now just build it. It doesn't take too long.

```bash
conda create --name gcloud --yes \
  gsutil
```


### Downloading the refdata

Download the refdata from Broad's Google Cloud.

```bash
REF_DIR="${SHARED_DIR}/reference-data"
mkdir -p "${REF_DIR}"
```

### Broad ref files download

This is a 'cloud-to-cloud' download, so it should be pretty fast.  
Remember to let these complete for commencing the workflow.

```bash
REF_DIR_BROAD="${REF_DIR}/broadinstitute/hg38"
mkdir -p "${REF_DIR_BROAD}"

ref_fasta_gcloud_dir_url="gs://gcp-public-data--broad-references/hg38/v0"

conda activate gcloud

## Download ref fasta files
sbatch --job-name "download_broad_ref_data" \
 --output="${LOG_DIR}/download_broad_ref_data.log" --error="${LOG_DIR}/download_broad_ref_fasta.log" \
 --wrap="gsutil cp \"${ref_fasta_gcloud_dir_url}/Homo_sapiens_assembly38.fasta*\" \"${REF_DIR_BROAD}/\""
 
## Download ref dict files
sbatch --job-name "download_broad_ref_data" \
 --output="${LOG_DIR}/download_broad_ref_data.log" --error="${LOG_DIR}/download_broad_ref_dict.log" \
 --wrap="gsutil cp \"${ref_fasta_gcloud_dir_url}/Homo_sapiens_assembly38.dict\" \"${REF_DIR_BROAD}/\""
 
conda deactivate
```

### Get intervals list

This creates a folder of fifty files which we then write to a file using find.  
This intervals file is pivotal for scattering over multiple contigs at once per sample.

```bash
## Create intervals dir and list file
interval_list_gcloud_dir="gs://gcp-public-data--broad-references/hg38/v0/scattered_calling_intervals/"
intervals_dir="${REF_DIR_BROAD}/hg38_wgs_scattered_calling_intervals"
intervals_list="${REF_DIR_BROAD}/hg38_wgs_scattered_calling_intervals.txt"

mkdir -p "${intervals_dir}"

conda activate gcloud

## Copy interval list
sbatch --wait \
  --job-name "download_scattered_calling_intervals_data" \
 --output="${LOG_DIR}/download_scattered_calling_data.log" --error="${LOG_DIR}/download_scattered_calling_data.log" \
 --wrap="gsutil -m rsync -r \"${interval_list_gcloud_dir}\" \"${intervals_dir}/\""

## Create intervals dir
find "${intervals_dir}" -type f > "${intervals_list}"

conda deactivate
```

### Download the input data

Download the input data from Broad's Google Cloud.  

```bash
INPUT_DIR="${SHARED_DIR}/input-data"
mkdir -p "${INPUT_DIR}"
```

### Broad input files download

These cram files are around 20Gb so may take a few minutes to download.  

```bash
INPUT_DIR_BROAD="${INPUT_DIR}/broadinstitute"
mkdir -p "${INPUT_DIR_BROAD}"

giab_data_gcloud_dir_url="gs://broad-public-datasets/NA12878/NA12878.bam*"

conda activate gcloud
sbatch --job-name "download_giab_data" \
 --output="${LOG_DIR}/download_giab_data.log" --error="${LOG_DIR}/download_giab_data.log" \
 --wrap="gsutil cp \"${giab_data_gcloud_dir_url}\" \"${INPUT_DIR_BROAD}\""
conda deactivate
```

### Get workflow

Haplotype caller is a standalone workflow - this means we don't need to zip up any helper scripts.

```bash
wdl_direct_download_link="https://raw.githubusercontent.com/gatk-workflows/gatk4-germline-snps-indels/master/haplotypecaller-gvcf-gatk4.wdl"

wget --output-document="haplotypecaller-gvcf-gatk4.wdl" \
  "${wdl_direct_download_link}"
```

### Set input json

Copy this file to `haplotype-caller.wdl.input.json` in your home directory.  
We will then use the `sed` command to change __SHARED_DIR__ to the proper absolute paths.

> If you use vim, you may wish to run `:set paste` to ensure the json is formatted correctly

```json
{
  "HaplotypeCallerGvcf_GATK4.input_bam": "__SHARED_DIR__/input-data/broadinstitute/NA12878.cram",
  "HaplotypeCallerGvcf_GATK4.input_bam_index": "__SHARED_DIR__/input-data/broadinstitute/NA12878.cram.crai",
  "HaplotypeCallerGvcf_GATK4.ref_dict": "__SHARED_DIR__/reference-data/broadinstitute/hg38/Homo_sapiens_assembly38.dict",
  "HaplotypeCallerGvcf_GATK4.ref_fasta": "__SHARED_DIR__/reference-data/broadinstitute/hg38/Homo_sapiens_assembly38.fasta",
  "HaplotypeCallerGvcf_GATK4.ref_fasta_index": "__SHARED_DIR__/reference-data/broadinstitute/hg38/Homo_sapiens_assembly38.fasta.fai",
  "HaplotypeCallerGvcf_GATK4.scattered_calling_intervals_list": "__SHARED_DIR__/reference-data/broadinstitute/hg38/hg38_wgs_scattered_calling_intervals.txt"
}
```

### Replace \_\_SHARED\_DIR\_\_

Replace the \_\_SHARED\_DIR\_\_ with the actual absolute path

```bash
sed -i "s%__SHARED_DIR__%${SHARED_DIR}%g" haplotype-caller.wdl.input.json
```

### Set up cromshell

cromshell is an easy way to talk to the cromwell server.  
We will go through the very basic commands in the next step.  

```bash
mkdir -p .cromshell
cromshell_config_file=".cromshell/cromwell_server.config"
cromwell_port="8000"

if [[ ! -f .cromshell/cromwell_server.config ]]; then
  echo "http://localhost:${cromwell_port}" > "${cromshell_config_file}"
fi
```

## Submit job to cromwell server through cromshell

Set the options file to `/opt/cromwell/configs/options.json`.  
You may wish to create your own options file.  
A list of available options can be found [here](https://cromwell.readthedocs.io/en/stable/wf_options/Overview/)


```bash
## workflow/inputs/options
cromshell submit \
  haplotypecaller-gvcf-gatk4.wdl \
  haplotype-caller.wdl.input.json \
  /opt/cromwell/configs/options.json
```

### Checking the status of a job

Ensure a workflow is running

```bash
cromshell status
```


### Check metadata of a job

Useful for debugging a workflow

```bash
cromshell metadata <WORKFLOW_ID>
```

## Where are my outputs

All files should be under `${SHARED_DIR}/cromwell/outputs`.  
This may be different if you have specified a different place in the `options.json`

## Uploading outputs to s3

By default, you do NOT have permissions to upload to S3.  
The following steps will allow you to have access to upload data to S3.  
You may then run a sync command to upload your output data to your bucket of choice.  

1. Head to the EC2 console, there you will see your master node in the running instances.  
2. Check the IAM role, it should start with `parallel-cluster..`
3. Click on the role and it should bring you to the role summary page.  
4. Click `Attach policies`. Search for `AmazonS3FullAccess`.

You may now run `aws s3 sync /path/to/outputs s3://my-bucket/` to upload your data for safe keeping.