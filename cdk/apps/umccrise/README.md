# UMCCRise Batch setup

## Usage
Invoke a lambda function to kick off a UMCCRise Batch job.
```bash
# minimal parameters (assumes default production settings)
aws lambda invoke \
    --function-name umccrise_batch_lambda \
    --payload '{ "inputDir": "Patients/SBJ00001/WGS/2019-03-20"}' \
    /tmp/lambda.output

# overwrite selected parameters to customise job, e.g. take data a from different data bucket and customise compute resources
aws lambda invoke \
    --function-name umccrise_batch_lambda \
    --payload '{ "inputDir": "Patients/SBJ00001/WGS/2019-03-20", "imageVersion": "0.15.15", "dataBucket": "umccr-validation-prod", "memory": "112640", "vcpus": "32"}' \
    /tmp/lambda.output
```

## Payload parameters

Required:
- inputDir: the path of the analysis result to run the job on

Optional:
- imageVersion: the umccrise image version to use for the job (only configurable in `dev`). Default: defined in default JobDefinition.
- memory: the memory the job will have available (in MiB). Default: `51200`
- vcpus: the vCPUs the job will have available. Default: `16`
- inputBucket: the S3 bucket holding the analysis result data. Default: `umccr-primary-data-prod`
- refDataBucket: the S3 bucket holding the reference data. Default: `umccr-refdata-prod`
- resultBucket: the S3 bucket where results are written to. Default: the inputBucket
- jobName: the name to give to the Batch job. Default: inputBucket + "---" + inputDir.replace('/', '_').replace('.', '_')



# Welcome to your CDK Python project!

This is a blank project for Python development with CDK.

The `cdk.json` file tells the CDK Toolkit how to execute your app.

This project is set up like a standard Python project.  The initialization
process also creates a virtualenv within this project, stored under the .env
directory.  To create the virtualenv it assumes that there is a `python3`
(or `python` for Windows) executable in your path with access to the `venv`
package. If for any reason the automatic creation of the virtualenv fails,
you can create the virtualenv manually.

To manually create a virtualenv on MacOS and Linux:

```
$ python3 -m venv .env
```

After the init process completes and the virtualenv is created, you can use the following
step to activate your virtualenv.

```
$ source .env/bin/activate
```

If you are a Windows platform, you would activate the virtualenv like this:

```
% .env\Scripts\activate.bat
```

Once the virtualenv is activated, you can install the required dependencies.

```
$ pip install -r requirements.txt
```

At this point you can now synthesize the CloudFormation template for this code.

```
$ cdk synth
```

To add additional dependencies, for example other CDK libraries, just add
them to your `setup.py` file and rerun the `pip install -r requirements.txt`
command.

# Useful commands

 * `cdk ls`          list all stacks in the app
 * `cdk synth`       emits the synthesized CloudFormation template
 * `cdk deploy`      deploy this stack to your default AWS account/region
 * `cdk diff`        compare deployed stack with current state
 * `cdk docs`        open CDK documentation

Enjoy!
