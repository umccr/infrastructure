# WTS REPORT

## S3 Trigger
A WTS report run can be executed automatically via upload of a trigger file, called `wts_complete`, to the approproate location in the S3 bucket (i.e. buckets `umccr-primary-data-prod`/`umccr-primary-data-dev2` in the `prod`/`dev` environment).

Make sure the trigger file is uploaded to the same location as and *after* all other analysis results. The process checks for WGS data and will incorporate it if present, but a WTS report generation goes ahead even if no WGS data is available/was found. The trigger file can be placed automatically or manually.

Example via the AWS CLI:
```bash
# check the content of the target location
$ aws s3 ls s3://umccr-primary-data-dev/Patients/Subject123/WTS/2019-08-23/
    PRE config/
    PRE final/

# upload the trigger file
$ touch /tmp/wts_complete && aws s3 cp /tmp/wts_complete s3://umccr-primary-data-dev/Patients/Subject123/WTS/2019-08-23/
```

An AWS Batch job will produce an output directory at the same level as the trigger file. To re-run a WTS report, just remove the trigger file and upload it again. However, please be aware that previous results/reports will be overwritten.
