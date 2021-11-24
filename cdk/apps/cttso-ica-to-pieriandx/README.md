# Welcome to your CDK Python project!

This is a blank project for Python development with CDK.

The `cdk.json` file tells the CDK Toolkit how to execute your app.

~~This project is set up like a standard Python project.  The initialization
process also creates a virtualenv within this project, stored under the `.venv`
directory.  To create the virtualenv it assumes that there is a `python3`
(or `python` for Windows) executable in your path with access to the `venv`
package. If for any reason the automatic creation of the virtualenv fails,
you can create the virtualenv manually.~~

Recreate with conda

```bash
conda create --name cttso-ica-to-pieriandx-cdk \
  --channel conda-forge \
  nodejs==16.12.0 \
  pip \
  setuptools
  
conda activate cttso-ica-to-pieriandx-cdk
 
pip install -r requirements.txt
```

To add additional dependencies, for example other CDK libraries, just add
them to your `setup.py` file and rerun the `pip install -r requirements.txt`
command.

## Viewing your project

```
$ cdk synth
```

## Deploying your project

```
# Login via sso
aws sso login -p dev # Change 'dev' to 'prod' if deploying in prod env

# Export AWS secrets to env (cdk doesn't support SSO yet)
. <(yawsso -e -p dev)  # Change 'dev' to 'prod' if deploying in prod env
 
# Update parameters
bash update-params.sh

# Check differences between local and remote stacks
cdk diff --all

# Deploy stacks
cdk deploy --all
```

## Other Useful commands
 * `cdk docs`        open CDK documentation

