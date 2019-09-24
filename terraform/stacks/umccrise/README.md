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

# to list the umccrise Docker container version used in the Batch job
aws batch describe-job-definitions \
    --job-definition-name umccrise_job_prod \
    --status ACTIVE \
    --query "jobDefinitions[*].containerProperties.image"
```

Each AWS Batch umccrise job will overwrite any existing output in the `umccrised` directory at the same level as the bcbio results. Rerunning a job will therefore result in the loss of the previous results.
