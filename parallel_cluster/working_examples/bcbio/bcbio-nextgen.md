# Bcbio on parallel cluster walkthrough

**An AWS parallel cluster walkthrough**

**This workflow currently fails with the following error. I need assistance debugging this**

```bash
subprocess.CalledProcessError: Command 'set -o pipefail; unset JAVA_HOME && /usr/local/share/bcbio-nextgen/anaconda/bin/bwa mem   -c 250 -M -t 13  -R '@RG\tID:NA12878\tPL:illumina\tPU:NA12878\tSM:NA12878' -v 1 /usr/local/share/bcbio-nextgen/genomes/Hsapiens/hg38/bwa/hg38.fa <(grabix grab /mnt/work/align_prep/NA12878-NGv3-LAB1360-A_1.fastq.gz 1 80000000) <(grabix grab /mnt/work/align_prep/NA12878-NGv3-LAB1360-A_2.fastq.gz 1 80000000)  | /usr/local/share/bcbio-nextgen/anaconda/bin/samtools sort -n -@ 13 -m 2G -O bam -T /mnt/work/bcbiotx/tmpxlsg5w4q/NA12878-sort-1_80000000-sorttmp-namesort -o /mnt/work/bcbiotx/tmpxlsg5w4q/NA12878-sort-1_80000000.bam -
/bin/bash: line 1:   103 Segmentation fault      (core dumped) /usr/local/share/bcbio-nextgen/anaconda/bin/bwa mem -c 250 -M -t 13 -R '@RG\tID:NA12878\tPL:illumina\tPU:NA12878\tSM:NA12878' -v 1 /usr/local/share/bcbio-nextgen/genomes/Hsapiens/hg38/bwa/hg38.fa <(grabix grab /mnt/work/align_prep/NA12878-NGv3-LAB1360-A_1.fastq.gz 1 80000000) <(grabix grab /mnt/work/align_prep/NA12878-NGv3-LAB1360-A_2.fastq.gz 1 80000000)
       104 Done                    | /usr/local/share/bcbio-nextgen/anaconda/bin/samtools sort -n -@ 13 -m 2G -O bam -T /mnt/work/bcbiotx/tmpxlsg5w4q/NA12878-sort-1_80000000-sorttmp-namesort -o /mnt/work/bcbiotx/tmpxlsg5w4q/NA12878-sort-1_80000000.bam -
' returned non-zero exit status 139.
' returned non-zero exit status 1.
```

## Overview

This is a rather complex example of running bcbio-nextgen through parallel cluster.  
The following code will:

1. Set up a parallel cluster through cloud formation.
2. Download the reference data and input data through sbatch commands.
   * These jobs are run on compute nodes. You will need to make sure they complete
     before running the bcbio workflow
3. Download the configuration files
4. Update the bcbio nextgen workflow
5. Patiently wait for the workflow to finish/
6. Upload the data to your preferred S3 bucket.

## Starting the cluster

The cluster uses the `umccr_dev` template. This command is launched from the umccr/infrastructure repo under the parallel cluster directory. Assumes sso login and pcluster env is activated.

### Command from local machine

```{bash start_cluster, echo=TRUE, eval=FALSE}
./bin/start_cluster.sh --cluster-template umccr_dev AlexisGPL`
ssm i-XXXX
```

## Setup 

### Declare shared directory

`SHARED_DIR` should already be in your `~/.bashrc`.

```{bash get_shared_dir, echo=TRUE, eval=FALSE}
if [[ ! -v SHARED_DIR ]]; then
  SHARED_DIR="/efs"  # /fsx if the umccr_dev_fsx cluster template was used
fi
```

### Create the logs directory

Let's create a folder `logs` in our home directory

```{bash create_logs, echo=TRUE, eval=FALSE}
LOG_DIR="${HOME}/logs"
mkdir -p "${LOG_DIR}"
```

### Downloading the refdata

Download the refdata from our S3 bucket.
Much faster than building from scratch.

```{bash create_ref_dir, echo=TRUE, eval=FALSE}
REF_DIR="${SHARED_DIR}/reference-data"
mkdir -p "${REF_DIR}"

REF_DIR_BCBIO="${REF_DIR}/bcbio/hg38"
mkdir -p "${REF_DIR_BCBIO}"
```

Now run an aws sync command from our s3 bucket

```{bash download_ref_dir, echo=TRUE, eval=FALSE}
s3_bcbio_path="s3://umccr-research-dev/parallel-cluster/bcbio/refdata/hg38"

aws s3 sync "${s3_bcbio_path}/" "${REF_DIR_BCBIO}/"
```

### Update refdata

```{bash update_ref_dir, echo=TRUE, eval=FALSE}

conda activate bcbio_nextgen_vm

sbatch --job-name update-bcbio \
  --output=${LOG_DIR}/bcbio-update.log --error=${LOG_DIR}/bcbio-update.log \
  --wrap="bcbio_vm.py \
            --datadir=\"${REF_DIR_BCBIO}\" \
            upgrade \
              --image=\"quay.io/bcbio/bcbio-vc\" \
              --data \
              --tools \
              --genomes hg38 \
              --aligners bwa \
              --aligners star"
```

### Create workdir

This is where the execution engine will run

```{bash create_workdir, echo=TRUE, eval=FALSE}
BCBIO_WORKDIR="${SHARED_DIR}/bcbio/workdir"

mkdir -p "${BCBIO_WORKDIR}"

BCBIO_CONFIG_FILE="${HOME}/sample-config.yaml"

# Also build the output dir
mkdir -p "${SHARED_DIR}/bcbio/outdir"
```


### Get inputs

We also place the inputs in our shared filesystem..

```{bash set_inputs_dir, echo=TRUE, eval=FALSE}
INPUT_DIR="${SHARED_DIR}/input-data"
mkdir -p "${INPUT_DIR}"

INPUT_DIR_BCBIO="${INPUT_DIR}/bcbio/"

mkdir -p "${INPUT_DIR_BCBIO}"
```

### Get fastqs

Download the fastq files from AWS.

```{bash get_fastq_files, echo=TRUE, eval=FALSE}

sbatch --job-name get-R1_fastq \
  --output="${LOG_DIR}/get-R1_fastq.log" --error="${LOG_DIR}/get-R1_fastq.log" \
  --wrap="wget --output-document \"${INPUT_DIR_BCBIO}/NA12878-NGv3-LAB1360-A_1.fastq.gz\" \
           \"https://s3.amazonaws.com/bcbio_nextgen/NA12878-NGv3-LAB1360-A_1.fastq.gz\""
sbatch --job-name get-R2_fastq \
  --output="${LOG_DIR}/get-R2_fastq.log" --error="${LOG_DIR}/get-R2_fastq.log" \
  --wrap="wget --output-document \"${INPUT_DIR_BCBIO}/NA12878-NGv3-LAB1360-A_2.fastq.gz\" \
           \"https://s3.amazonaws.com/bcbio_nextgen/NA12878-NGv3-LAB1360-A_2.fastq.gz\""
```


### Get Config

Write the following to the `BCBIO_CONFIG_FILE`

```{yaml get_config_file, echo=TRUE, eval=FALSE}
# Configuration comparing alignment methods, preparation approaches
# and variant callers for an NA12878 exome dataset from EdgeBio.
#
# See the bcbio-nextgen documentation for full instructions to
# run this analysis:
# https://bcbio-nextgen.readthedocs.org/en/latest/contents/testing.html#example-pipelines
---
upload:
  dir: __SHARED_DIR__/bcbio/outputs/final
details:
  - files: 
    - __SHARED_DIR__/input-data/bcbio/NA12878-NGv3-LAB1360-A_1.fastq.gz
    - __SHARED_DIR__/input-data/bcbio/NA12878-NGv3-LAB1360-A_2.fastq.gz
    description: NA12878
    metadata:
      sex: female
    analysis: variant2
    genome_build: hg38
    algorithm:
      aligner: bwa
      variantcaller: gatk-haplotype
      validate: giab-NA12878/truth_small_variants.vcf.gz
      validate_regions: giab-NA12878/truth_regions.bed
      variant_regions: capture_regions/Exome-NGv3
```

Then use sed to update to the actual absolute path

```{bash update_config_file, echo=TRUE, eval=FALSE}
sed -i "s%__SHARED_DIR__%${SHARED_DIR}%g" "${BCBIO_CONFIG_FILE}"
```

## Run the project

We run two commands at once, the update then the install. 
Although we just updated the repo, this ensures that the right image is downloaded to this instance.  

The update should not take more than a couple of minutes.  

Then the run will start.

We specify numcores to 32, this will split an array of two jobs over four separate compute instances.

```{bash run_project, echo=TRUE, eval=FALSE}
conda activate bcbio_nextgen_vm

sbatch --job-name run-bcbio \
  --output="${LOG_DIR}/run-bcbio.%j.log" --error="${LOG_DIR}/run-bcbio.%j.log" \
  --chdir="${BCBIO_WORKDIR}" \
  --wrap="bcbio_vm.py \
            --datadir=\"${REF_DIR_BCBIO}\" \
            upgrade \
              --data \
              --tools \
              --image=\"quay.io/bcbio/bcbio-vc\" && \
          bcbio_vm.py --datadir \"${REF_DIR_BCBIO}\" \
            ipython \
              \"${BCBIO_CONFIG_FILE}\" \
              \"slurm\" \
              \"compute\" \
              --image \"quay.io/bcbio/bcbio-vc\" \
              --numcores \"32\" \
              --systemconfig \"${REF_DIR_BCBIO}/galaxy/bcbio_system.yaml\""
```

## Where's my data

If the run is successful, you can find the data in "${SHARED_DIR}/bcbio/outputs/final",
as this is where we set it in the config file.

You may wish to view [this readme](https://bcbio-nextgen.readthedocs.io/en/latest/contents/intro.html?highlight=NA12878#explore-results-in-na12878-exome-eval-final) to delve into the results files

## Uploading outputs to s3

By default, you do NOT have permissions to upload to S3.  
The following steps will allow you to have access to upload data to S3.  
You may then run a sync command to upload your output data to your bucket of choice.  

1. Head to the EC2 console, there you will see your master node in the running instances.  
   Check the IAM role, it should start with `parallel-cluster..`
2. Click on the role and it should bring you to the role summary page.  
3. Click `Attach policies`. Search for `AmazonS3FullAccess`.

You may now run `aws s3 sync /path/to/outputs s3://my-bucket/`.