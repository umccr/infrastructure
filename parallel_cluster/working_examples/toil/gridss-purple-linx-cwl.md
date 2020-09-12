# Gridss-purple-linx

**An AWS parallel cluster walkthrough**

## Overview

This is a rather complex example of running CWL through parallel cluster.  
The following code will:

1. Set up a parallel cluster through cloud formation.
2. Download the reference data and input data through sbatch commands.
   * These jobs are run on compute nodes. You will need to make sure they complete
     before running the CWL workflow
4. Download and configure the input-json for the CWL workflow
5. Launch the CWL workflow through toil
6. Patiently wait for the job to finish.
7. Upload the data to your preferred S3 bucket.

### Sources:

The following workflow is based on the gridss-purple-linx workflow 
from [this repo](https://github.com/hartwigmedical/gridss-purple-linx/)

Much of the reference data is downloaded from the Hartwig nextcloud.

### Further reading

* [Toil Docs](https://toil.readthedocs.io/en/latest/)
* [CWL Docs](https://www.commonwl.org/user_guide/aio/index.html)
* [Slurm Docs](https://slurm.schedmd.com/sbatch.html)

## Starting the cluster

The cluster uses the `umccr_dev` template.  
This command is launched from the umccr/infrastructure repo under the `parallel_cluster` directory. 

Assumes sso login has been completed and pcluster conda env is activated.

### Command from local machine

```{bash start_cluster, echo=TRUE, eval=FALSE}
./bin/start_cluster.sh --cluster-template umccr_dev AlexisGPL`
ssm i-XXXX
```

### Declare shared directory

This should be in your `~/.bashrc` profile.

```{bash get_shared_dir, echo=TRUE, eval=FALSE}
if [[ ! -v SHARED_DIR ]]; then
  SHARED_DIR="/efs"  # /fsx if the umccr_dev_fsx cluster template was used
fi
```

## Create the logs directory

```{bash create_logs, echo=TRUE, eval=FALSE}
LOG_DIR="${HOME}/logs"
mkdir -p "${LOG_DIR}"
```

## Downloading the refdata

Download the refdata from the nextcloud and our hg38 ref set - 
I would recommend moving this to your own s3 bucket for multiple uses.

Will make downloading a lot faster and reliable.

```{bash create_ref_dir, echo=TRUE, eval=FALSE}
REF_DIR="${SHARED_DIR}/reference-data"
mkdir -p "${REF_DIR}"
```

### Commands for hartwig nextcloud dataset

These are subject to timeouts, so please ensure they do download correctly.

If they have downloaded correctly, there should not be any zip files under `${REF_DIR}/hartwig-nextcloud`

```{bash create_hmf_ref_data_dir, echo=TRUE, eval=FALSE}
REF_DIR_HARTWIG="${REF_DIR}/hartwig-nextcloud"
mkdir -p "${REF_DIR_HARTWIG}"
```

#### Amber files

```{bash download_amber_files, echo=TRUE, eval=FALSE}
direct_download_link="https://nextcloud.hartwigmedicalfoundation.nl/s/LTiKTd8XxBqwaiC/download?path=%2FHMFTools-Resources%2FAmber"
sbatch --job-name "amber_download_logs" \
  --output logs/amber_download_logs.log --error logs/amber_download_logs.log \
  --wrap "wget --output-document \"${REF_DIR_HARTWIG}/Amber.zip\" \
            \"${direct_download_link}\" && \
          unzip -d \"${REF_DIR_HARTWIG}/\" \"${REF_DIR_HARTWIG}/Amber.zip\" && \
          rm \"${REF_DIR_HARTWIG}/Amber.zip\""
```

#### GRIDSS Files

```{bash download_gridss_files, echo=TRUE, eval=FALSE}
direct_download_link="https://nextcloud.hartwigmedicalfoundation.nl/s/LTiKTd8XxBqwaiC/download?path=%2FHMFTools-Resources%2FGRIDSS"
sbatch --job-name="gridss-data-download" \
  --output logs/GRIDSS_download_logs.log --error logs/GRIDSS_download_logs.log \
  --wrap "wget --output-document \"${REF_DIR_HARTWIG}/GRIDSS.zip\" \
            \"${direct_download_link}\" && \
          unzip -d \"${REF_DIR_HARTWIG}/\" \"${REF_DIR_HARTWIG}/GRIDSS.zip\" && \
          rm \"${REF_DIR_HARTWIG}/GRIDSS.zip\""
```

#### DOCKER FILES

Need the promiscuous files out of here

```{bash download_promiscuous_files, echo=TRUE, eval=FALSE}
direct_download_link="https://nextcloud.hartwigmedicalfoundation.nl/s/LTiKTd8XxBqwaiC/download?path=%2FHMFTools-Resources%2FGRIDSS-Purple-Linx-Docker"
sbatch --job-name="hg19-dockerfiles-download" \
  --output logs/DOCKER_download_logs.log --error logs/DOCKER_download_logs.log \
  --wrap "wget --output-document \"${REF_DIR_HARTWIG}/DOCKER.zip\" \
            \"${direct_download_link}\" && \
          unzip -d ${REF_DIR_HARTWIG}/ \"${REF_DIR_HARTWIG}/DOCKER.zip\" && \
          rm \"${REF_DIR_HARTWIG}/DOCKER.zip\" && \
          tar -C \"${REF_DIR_HARTWIG}/GRIDSS-Purple-Linx-Docker/\" \
            -xf \"${REF_DIR_HARTWIG}/GRIDSS-Purple-Linx-Docker/gridss-purple-linx-hg19-refdata-Dec2019.tar.gz\" && \
          rm \"${REF_DIR_HARTWIG}/GRIDSS-Purple-Linx-Docker/gridss-purple-linx-hg19-refdata-Dec2019.tar.gz\""
```

#### LINX Files

```{bash download_linx_files, echo=TRUE, eval=FALSE}
direct_download_link="https://nextcloud.hartwigmedicalfoundation.nl/s/LTiKTd8XxBqwaiC/download?path=%2FHMFTools-Resources%2FLinx"
sbatch --job-name "linx-download" \
  --output logs/linx_download_logs.log --error logs/linx_download_logs.log \
  --wrap "wget --output-document ${REF_DIR_HARTWIG}/linx.zip \
            \"${direct_download_link}\" && \
          unzip -d \"${REF_DIR_HARTWIG}/\" \"${REF_DIR_HARTWIG}/linx.zip\" && \
          rm \"${REF_DIR_HARTWIG}/linx.zip\""
```

### Command for umccr-refdata-dev dataset

For running through hg38, we need a reference set.

```{bash create_umccr_ref_data_dir, echo=TRUE, eval=FALSE}
REF_DIR_UMCCR="${REF_DIR}/umccr"
mkdir -p "${REF_DIR_UMCCR}"
```

#### HG38 Genome Data

```{bash download_genomic_data, echo=TRUE, eval=FALSE}
sbatch --job-name "umccr_aws_sync_logs" \
  --output logs/umccr_aws_sync_logs.log --error logs/umccr_aws_sync_logs.log \
  --wrap "aws s3 sync s3://umccr-refdata-dev/genomes/hg38/ \"${REF_DIR_UMCCR}/hg38/\""
```

## Downloading the input data

```{bash create_input_data_dir, echo=TRUE, eval=FALSE}
INPUT_DIR="${SHARED_DIR}/input-data"
mkdir -p "${INPUT_DIR}"
```

First we use our IAP command on our local machine to extract a presigned url, then use X to download that

### Get presigned urls

jq magic from [this stack overflow thread](https://stackoverflow.com/questions/34226370/jq-print-key-and-value-for-each-entry-in-an-object)  
> Use pbcopy instead of xclip if running on a mac  

Output in the following format:  
`name,presignedurl`

```{bash get_presigned_urls, echo=TRUE, eval=FALSE}
gds_input_data_path="gds://umccr-primary-data-dev/PD/SEQCII/hg38/SBJ_seqcii_020/"
iap files list "${gds_input_data_path}" \
  --output-format json \
  --max-items=0 \
  --nonrecursive \
  --with-access | \
jq --raw-output '.items | keys[] as $k | "\(.[$k] | .name),\(.[$k] | .presignedUrl)"' | \
xclip
```

Copy the clipboard into `presigned_urls.csv` on the parallel cluster master node

### Downloading from the presigned URL

```{bash download_input_data, echo=TRUE, eval=FALSE}
INPUT_DIR_IAP="${INPUT_DIR}/iap/SBJ_seqcii_020"

mkdir -p "${INPUT_DIR_IAP}"

while read p; do
  name=$(echo "${p}" | cut -d',' -f1)
  presigned_url=$(echo "${p}" | cut -d',' -f2)
  sbatch --job-name="${name}" \
    --output "logs/wget-${name}.log" --error "logs/wget-${name}.log" \
    --wrap "wget \"${presigned_url}\" --output-document \"${INPUT_DIR_IAP}/${name}\"" 
done <presigned_urls.csv
```

## Miscellaneous files to download

### Blacklist

```{bash create_black_list_dir, echo=TRUE, eval=FALSE}
REF_DIR_BOYLE_LAB="${REF_DIR}/Boyle-Lab"
mkdir -p "${REF_DIR_BOYLE_LAB}"
```

```{bash download_black_list, echo=TRUE, eval=FALSE}
direct_download_link="https://github.com/Boyle-Lab/Blacklist/raw/master/lists/hg38-blacklist.v2.bed.gz"
sbatch --job-name "hg38-blacklist-download" \
  --output logs/hg38-blacklist-download.log --error logs/hg38-blacklist-download.log \
  --wrap "wget  \"${direct_download_link}\" \
            --output-document \"${REF_DIR_BOYLE_LAB}hg38-blacklist.v2.bed.gz\""
```

### Gridss-purple-linx smoke test download

Run the git clone component inside a sub-shell,  
so `cd` does not affect the main shell.

```{bash download_smoke_test_from_github, echo=TRUE, eval=FALSE}
gridss_purple_linx_remote_url="https://github.com/hartwigmedical/gridss-purple-linx"
INPUT_DIR_GRIDSS_PURPLE_LINX_REPO="${INPUT_DIR}/gridss-purple-linx"
mkdir -p "${INPUT_DIR_GRIDSS_PURPLE_LINX_REPO}"
(
 cd ${INPUT_DIR_GRIDSS_PURPLE_LINX_REPO} && \
 git init && \
 git remote add -f origin "${gridss_purple_linx_remote_url}" && \
 git config core.sparseCheckout true && \
 echo "smoke_test" >> .git/info/sparse-checkout && \
 git pull origin master
)
```

## Initialising the input jsons

The input json for the cwl workflow smoke-test will look something like this.

### Smoke test

Write the following file to `gridss-purple-linx.packed.input-smoketest.json`

You may also wish to add the `.gridsscache` and `.img` files to the json under the `reference_cache_files_gridss` key.
This is extremely useful for debugging as it means gridss can skip the reference building stage.

> If using vim, you may wish to set paste (with :set paste) before inserting.
> This enables the right line recursion

```{json initialise_hg37_smoke_test_json_file, echo=TRUE, eval=FALSE}
{
  "sample_name": "CPCT12345678",
  "normal_sample": "CPCT12345678R",
  "tumor_sample": "CPCT12345678T",
  "tumor_bam": {
    "class": "File",
    "location": "__SHARED_DIR__/input-data/gridss-purple-linx/smoke_test/CPCT12345678T.bam"
  },
  "normal_bam": {
    "class": "File",
    "location": "__SHARED_DIR__/input-data/gridss-purple-linx/smoke_test/CPCT12345678R.bam"
  },
  "snvvcf": {
    "class": "File",
    "location": "__SHARED_DIR__/input-data/gridss-purple-linx/smoke_test/CPCT12345678T.somatic_caller_post_processed.vcf.gz"
  },
  "fasta_reference": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS-Purple-Linx-Docker/hg19/refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.fasta"
  },
  "reference_dict": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS-Purple-Linx-Docker/hg19/refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.dict"
  },
  "gc_profile": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS-Purple-Linx-Docker/hg19/dbs/gc/GC_profile.1000bp.cnp"
  },
  "blacklist_gridss": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS-Purple-Linx-Docker/hg19/dbs/gridss/ENCFF001TDO.bed"
  },
  "breakend_pon": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS-Purple-Linx-Docker/hg19/dbs/gridss/pon3792v1/gridss_pon_single_breakend.bed"
  },
  "breakpoint_pon": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS-Purple-Linx-Docker/hg19/dbs/gridss/pon3792v1/gridss_pon_breakpoint.bedpe"
  },
  "breakpoint_hotspot": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS/KnownFusionPairs.hg19.bedpe"
  },
  "bafsnps_amber": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS-Purple-Linx-Docker/hg19/dbs/germline_het_pon_hg19/GermlineHetPon.hg19.vcf.gz"
  }
  "known_fusion_data_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/known_fusion_data.hg19.csv"
  },
  "gene_transcripts_dir_linx": {
    "class": "Directory",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/ensemble_data_cache_hg19"
  },
  "viral_hosts_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/viral_host_ref.csv"
  },
  "replication_origins_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/heli_rep_origins.bed"
  },
  "line_element_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/line_elements.hg19.csv"
  },
  "fragile_site_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/fragile_sites_hmf.hg19.csv"
  }
}
```

### HG38 SBJ - large WGS dataset

Write the following file to `gridss-purple-linx.packed.input-SBJ_seqcii_020.json`

```{json initialise_hg38_SBJ_json_file, echo=TRUE, eval=FALSE}
{
  "sample_name": "SBJ_seqcii_020",
  "normal_sample": "seqcii_N020",
  "tumor_sample": "seqcii_T020",
  "tumor_bam": {
    "class": "File",
    "location": "__SHARED_DIR__/input-data/iap/SBJ_seqcii_020/SBJ_seqcii_020_tumor.bam"
  },
  "normal_bam": {
    "class": "File",
    "location": "__SHARED_DIR__/input-data/iap/SBJ_seqcii_020/SBJ_seqcii_020.bam"
  },
  "snvvcf": {
    "class": "File",
    "location": "__SHARED_DIR__/input-data/iap/SBJ_seqcii_020/SBJ_seqcii_020.vcf.gz"
  },
  "fasta_reference": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/umccr/hg38/hg38.fa"
  },
  "bwa_reference_files": [
    {
      "class": "File",
      "location": "__SHARED_DIR__/reference-data/umccr/hg38/bwa/hg38.fa.alt"
    },
    {
      "class": "File",
      "location": "__SHARED_DIR__/reference-data/umccr/hg38/bwa/hg38.fa.amb"
    },
    {
      "class": "File",
      "location": "__SHARED_DIR__/reference-data/umccr/hg38/bwa/hg38.fa.ann"
    },
    {
      "class": "File",
      "location": "__SHARED_DIR__/reference-data/umccr/hg38/bwa/hg38.fa.bwt"
    },
    {
      "class": "File",
      "location": "__SHARED_DIR__/reference-data/umccr/hg38/bwa/hg38.fa.pac"
    },
    {
      "class": "File",
      "location": "__SHARED_DIR__/reference-data/umccr/hg38/bwa/hg38.fa.sa"
    }
  ],
  "reference_dict": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/umccr/hg38/hg38.dict"
  },
  "gc_profile": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/umccr/hg38/hmf/GC_profile.1000bp.cnp"
  },
  "blacklist_gridss": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/Boyle-Lab/hg38-blacklist.v2.bed.gz"
  },
  "breakend_pon": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS/gridss_pon_single_breakend.hg38.bed"
  },
  "breakpoint_pon": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS/gridss_pon_breakpoint.hg38.bedpe"
  },
  "breakpoint_hotspot": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/GRIDSS/KnownFusionPairs.hg38.bedpe"
  },
  "bafsnps_amber": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Amber/GermlineHetPon.hg38.vcf.gz"
  },
  "known_fusion_data_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/known_fusion_data.hg38.csv"
  },
  "gene_transcripts_dir_linx": {
    "class": "Directory",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/ensemble_data_cache_hg38"
  },
  "viral_hosts_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/viral_host_ref.csv"
  },
  "replication_origins_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/heli_rep_origins.bed"
  },
  "line_element_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/line_elements.hg38.csv"
  },
  "fragile_site_file_linx": {
    "class": "File",
    "location": "__SHARED_DIR__/reference-data/hartwig-nextcloud/Linx/fragile_sites_hmf.hg38.csv"
  }
}
```

### Replace \_\_SHARED\_DIR\_\_

Replace the \_\_SHARED\_DIR\_\_ with the actual absolute path

```{bash write_shared_dir, echo=TRUE, eval=FALSE}
sed -i "s%__SHARED_DIR__%${SHARED_DIR}%g" gridss-purple-linx.packed.input-smoketest.json
sed -i "s%__SHARED_DIR__%${SHARED_DIR}%g" gridss-purple-linx.packed.input-SBJ_seqcii_020.json
```

## Downloading the workflow from GitHub

```{bash get_workflow_from_git_repo, echo=TRUE, eval=FALSE}
gridss_workflow_url_with_token="https://raw.githubusercontent.com/umccr-illumina/cwl-iap/master/workflows/gridss-purple-linx/0.1/iap-requests/gridss-purple-linx-0.1.packed.cwl.json?token=AB6RMGYOL5FVNKITJQK5JHC7MX4PU"
wget --output-document gridss-purple-linx-0.1.packed.cwl.json \
  "${gridss_workflow_url_with_token}"
```

## Running the workflow through toil
```{bash create_toil_dir, echo=TRUE, eval=FALSE}
TOIL_ROOT="${SHARED_DIR}/toil"
mkdir -p "${TOIL_ROOT}"
```

### Set env vars and create directories

```{bash set_toil_dir, echo=TRUE, eval=FALSE}
# Set globals
TOIL_JOB_STORE="${TOIL_ROOT}/job-store"
TOIL_WORKDIR="${TOIL_ROOT}/workdir"
TOIL_TMPDIR="${TOIL_ROOT}/tmpdir"
TOIL_LOG_DIR="${TOIL_ROOT}/logs"
TOIL_OUTPUTS="${TOIL_ROOT}/outputs"

# Create directories
mkdir -p "${TOIL_JOB_STORE}"
mkdir -p "${TOIL_WORKDIR}"
mkdir -p "${TOIL_TMPDIR}"
mkdir -p "${TOIL_LOG_DIR}"
mkdir -p "${TOIL_OUTPUTS}"

# Activate environment
conda activate toil
```

### Launch smoke test job 

You may need to first index the vcf file. Due to toil not fully supporting CWL v1.1.

`tabix -p /fsx/input-data/gridss-purple-linx/smoke_test/CPCT12345678T.somatic_caller_post_processed.vcf.gz`

```{bash launch_toil_smoke_test_task, echo=TRUE, eval=FALSE}
cleanworkdirtype="onSuccess"  # Switch to 'never' for further debugging.
gridss_purple_input_json="gridss-purple-linx.packed.input-smoketest.json"
sbatch --job-name "toil-gridss-purple-linx-runner" \
       --output "logs/toil.%j.log" --error "logs/toil.%j.log" \
       --wrap "toil-cwl-runner \
                 --jobStore \"${TOIL_JOB_STORE}/job-\${SLURM_JOB_ID}\" \
                 --workDir \"${TOIL_WORKDIR}\" \
                 --outdir \"${TOIL_OUTPUTS}\" \
                 --batchSystem slurm \
                 --writeLogs \"${TOIL_LOG_DIR}\" \
                 --writeLogsFromAllJobs \
                 --cleanWorkDir=\"${cleanworkdirtype}\" \
                 \"gridss-purple-linx.packed.cwl.json\" \
                 \"${gridss_purple_input_json}\""
```

This job will likely fail because the gripss hard-filtering is too strict.  
I am in the processing of creating an issue for the hartwig team on this, 
to see if more example data can be made - or parameters can be tweaked so this job can continue past the purple stage?
 
### Launch SBJ Seqcii HG38 Job

```{bash launch_toil_seqcii_task, echo=TRUE, eval=FALSE}
cleanworkdirtype="onSuccess"  # Switch to 'never' for further debugging.
gridss_purple_input_json="gridss-purple-linx.packed.input-SBJ_seqcii_020.json"
sbatch  --job-name "toil-gridss-purple-linx-runner" \
  --output "logs/toil.%j.log" --error "logs/toil.%j.log" \
    --wrap "toil-cwl-runner \
              --jobStore \"${TOIL_JOB_STORE}/job-\${SLURM_JOB_ID}\" \
              --workDir \"${TOIL_WORKDIR}\" \
              --outdir \"${TOIL_OUTPUTS}\" \
              --batchSystem slurm \
              --writeLogs \"${TOIL_LOG_DIR}\" \
              --writeLogsFromAllJobs \
              --cleanWorkDir=\"${cleanworkdirtype}\" \
              \"gridss-purple-linx.packed.cwl.json\" \
              \"${gridss_purple_input_json}\""
```

This workflow may take a full day to complete!
