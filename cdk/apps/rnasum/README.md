# RNAsum CDK app

AWS infrastructure related to the RNAsum service.

## Launch a RNAsum IAP task

An IAP task can be launched using a submission Lambda in our `dev` account:

```
aws lambda invoke --function-name rnasum_iap_tes_lambda_dev \
                  --payload '{"gdsWtsDataFolder":"gds://umccr-primary-data-dev/UMCCR-Testing/SBJ99999/WTS/2019-12-11/final/SBJ99999_PRJ999999_L9999999", "gdsWgsDataFolder":"gds://umccr-primary-data-dev/UMCCR-Testing/SBJ99999/WGS/2019-12-11/umccrised/SBJ99999_PRJ999999_L9999999"}' \
                  /tmp/lambda.output
```

The `gdsWgsDataFolder` parameter can be omitted when no WGS results are available, the execution will default to the WTS only mode.

Additional payload parameters can be specified to customise execution aspects:
- `refDataName`: the name for the reference dataset. Default: PANCAN
- `imageName`: the name of the docker image to use. Default: umccr/rnasum
- `imageTag`: the version/tag of the docker image to use.
- `gdsRefDataFolder`: the GDS URL of the reference data to use. Default: gds://umccr-refdata-dev/RNAsum/data/
- `gdsOutputDataFolder`: the GDS URL where to store the output. Default: derived from gdsWtsDataFolder


# Working with this CDK project

## Welcome to your CDK Python project!

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

Once the virtualenv is activated, you can install the required dependencies.

```
$ pip install -r requirements.txt
```

List available stacks

```
$ cdk list
```

At this point you can now synthesize the CloudFormation template for this code.

```
$ cdk synth <stack name>
```

Deploy a stack to AWS

```
$ cdk deploy <stack name>
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
