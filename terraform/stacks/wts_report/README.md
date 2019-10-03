# WTS REPORT

To trigger a WTS report Batch job, call the job submission lambda via the AWS CLI.

NOTE: the `prod_operator` role has the necessary priviledges to invoke the lambda

The only required parameter is `dataDirWTS`, the sample "directory" of the WTS bcBio result.
NOTE: IN the normal case both WGS and WTS should be available.
```bash
# invoke the WTS report lambda
aws lambda invoke \
    --function-name wts_report_trigger_lambda_prod  \
    --payload '{"dataDirWGS":"wts-report-test/WGS/2019-09-26/umccrised/SAMPLE123", "dataDirWTS":"wts-report-test/WTS/2019-09-26/final/SAMPLE123"}'
    /tmp/lambda.output

# to run on data in the temp bucket or to change memory/cpu requirements
aws lambda invoke \
    --function-name wts_report_trigger_lambda_prod  \
    --payload '{"dataDirWGS":"wts-report-test/WGS/2019-09-26/umccrised/SAMPLE123", "dataDirWTS":"wts-report-test/WTS/2019-09-26/final/SAMPLE123", "dataBucket":"umccr-temp", "memory":"32000", "vcpus":"8", "refDataset":"PANCAN"}'
    /tmp/lambda.output

# to list the umccr/wtsreport Docker container version used in the Batch job
aws batch describe-job-definitions \
    --job-definition-name wts_report_job_prod \
    --status ACTIVE \
    --query "jobDefinitions[*].containerProperties.image"
```

Each AWS Batch wts_report job will overwrite any existing output in the `wts-report` directory. Rerunning a job will therefore result in the loss of the previous results.
