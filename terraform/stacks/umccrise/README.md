# UMCCRISE

To trigger a umccrise Batch job, call the the job submission lambda.

NOTE: the `prod_operator` role has the necessary priviledges to invoke the lambda

The only required parameter is `resultDir`, the "directory" of the bcbio results to run `umccrise` on, i.e. the S3 path where the `final` and `config` folders are located.
```bash
# invoke the umccrise lambda
aws lambda invoke \
    --function-name umccrise_lambda_prod \
    --payload '{ "resultDir": "Patients/SBJ00001/WGS/2019-03-20"}' \
    /tmp/lambda.output

# to run on data in the temp bucket or to change memory/cpu requirements
aws lambda invoke \
    --function-name umccrise_lambda_prod \
    --payload '{ "resultDir": "Patients/SBJ00001/WGS/2019-03-20", "dataBucket": "umccr-temp", "memory": "50000", "vcpus": "16"}' \
    /tmp/lambda.output
# NOTE: the jobid is stored in the output file /tmp/lambda.output

# to list the umccrise Docker container version used in the Batch job
aws batch describe-job-definitions \
    --job-definition-name umccrise_job_prod \
    --status ACTIVE \
    --query "jobDefinitions[*].containerProperties.image"

# list batch jobs
aws batch list-jobs

# terminate a job and give a reason
aws batch terminate-job --job-id 5f81c2a3-f21a-49fa-a3b6-127bc0e8a972 --reason "Wrong parameters provided"
```

Each AWS Batch umccrise job will overwrite any existing output in the `umccrised` directory at the same level as the bcbio results. Rerunning a job will therefore result in the loss of the previous results.


# Testing in `dev`
For testing purposes one can run `umccrise` in the `dev` account accessing `prod` data.
NOTE: the `resultBucket` defaults to the `dataBucket`. The `dev` account does not have write access to the `prod` buckets, so if the `dataBucket` is overwritten to read from `prod` (while running in `dev`), the `resultBucket` has to be explicitly set to a writable bucket in the `dev` account.

```bash
aws lambda invoke \
    --function-name umccrise_lambda_dev \
    --payload '{ "resultDir": "Patients/SBJ00001/WGS/2019-03-20", "dataBucket": "umccr-primary-data-prod", "resultBucket": "umccr-primary-data-dev"}' \
    /tmp/lambda.output

```