# UMCCRISE

## S3 Trigger
A umccrise run can be executed automatically via upload of a trigger file, called `upload_complete`, to the approproate location in the S3 bucket (i.e. buckets `umccr-primary-data-prod`/`umccr-primary-data-dev` in the `prod`/`dev` environment).

Make sure the trigger file is uploaded to the same location as and *after* all other analysis results (e.g. the bcbio `final` and `config` output directories). The trigger file can be placed automatically or manually.

Example via the AWS CLI:
```bash
# check the content of the target location
$ aws s3 ls s3://umccr-primary-data-dev/Patients/2019-06-07/
    PRE config/
    PRE final/

# upload the trigger file
$ touch upload_complete && aws s3 cp upload_complete s3://umccr-primary-data-dev/Patients/2019-06-07/
```

Each AWS Batch umccrise job will produce a timestamped output directory at the same level as the bcbio results and the trigger file. The timestamp allows the repetition of umccrise runs without overwriting existing data. To rerun umccrise, just remove the trigger file and upload it again. However, please be aware that unnecessary/duplicated umccrise results need to be cleaned up manually.
