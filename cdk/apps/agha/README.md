
# Welcome to your CDK Python project!

- [Welcome to your CDK Python project!](#welcome-to-your-cdk-python-project)
  - [Useful commands](#useful-commands)
  - [Stacks](#stacks)
    - [agha_stack](#agha_stack)

This is a CDK project for AGHA.

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

## Useful commands

 * `cdk ls`          list all stacks in the app
 * `cdk synth`       emits the synthesized CloudFormation template
 * `cdk deploy`      deploy this stack to your default AWS account/region
 * `cdk diff`        compare deployed stack with current state
 * `cdk docs`        open CDK documentation

## Stacks

### agha_stack
This stack contains a Lambda to run AGHA submission validations comparing the submitted `manifest.txt` file to the content of the corresponding S3 "folder".

NOTE: this stack deploys a Lambda layer to provide `pandas` support to the Lambda. This requires that the pandas deployment package is build prior to deploying the stack.

In the `lambdas/layers/pandas` direcctory execute the `get_layer_packages.sh` script, which will generate the `lambdas/layers/pandas/python37-pandas.zip` referenced in the stack.