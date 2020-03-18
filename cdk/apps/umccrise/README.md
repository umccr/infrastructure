# UMCCRise Batch setup

## Usage
Invoke a lambda function to kick off a UMCCRise Batch job.
```bash
# minimal parameters (assumes default production settins)
aws lambda invoke \
    --function-name umccrise_lambda_prod \
    --payload '{ "resultDir": "Patients/SBJ00001/WGS/2019-03-20", "imageVersion": "0.15.15"}' \
    /tmp/lambda.output

# overwrite selected parameters to customise job, e.g. take data from different data bucket and customise compute resource
aws lambda invoke \
    --function-name umccrise_lambda_prod \
    --payload '{ "resultDir": "Patients/SBJ00001/WGS/2019-03-20", "imageVersion": "0.15.15", "dataBucket": "umccr-temp", "memory": "50000", "vcpus": "16"}' \
    /tmp/lambda.output
```

## Payload parameters

Required:
- resultDir: the path of the analysis result to run the job on
- imageVersion: the umccrise image version to use for the job

Optional:
- memory: the memory the job will have available (in MB). Default: `2048`
- vcpus: the vCPUs the job will have available. Default: `2`
- dataBucket: the S3 bucket holding the analysis result data. Default: `umccr-primary-data-prod`
- refDataBucket: the S3 bucket holding the reference data. Default: `umccr-refdata-prod`
- resultBucket: the S3 bucket where results are written to. Defaults to the dataBucket
- jobName: the name to give to the Batch job. Default: dataBucket + "---" + resultDir.replace('/', '_').replace('.', '_')

# Useful commands

 * `cdk ls`          list all stacks in the app
 * `cdk synth`       emits the synthesized CloudFormation template
 * `cdk deploy`      deploy this stack to your default AWS account/region
 * `cdk diff`        compare deployed stack with current state
 * `cdk docs`        open CDK documentation

Enjoy!
