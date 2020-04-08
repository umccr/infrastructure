
# Dev worker project

Deploy an ec2 instance with docker ready to go and logged into our ECR (Elastic container registry)

This repo is (partially) based on the cdk example provided [here](https://github.com/aws-samples/aws-cdk-examples/blob/master/python/existing-vpc-new-ec2-ebs-userdata/cdk_vpc_ec2)

## Quick start:
1. Create the venv
`python3 -m venv .env`
2. Activate the venv
`source .env/bin/activate`
3. Deploy the ec2 instance:
`cdk deploy`

## Observe the cdk.json
We have the following variables as default:
* EC2_TYPE: m4.4xlarge
* MACHINE_IMAGE: ami-0dc96254d5535925f
* VOLUME_SIZE: "100"
* MOUNT_POINT: "/dev/xvdh"

    
## Setup the stack
There are two main things under the stack script that  
are characteristic to this workflow 
1. Policies to allow pulling of containers from our ECR and S3 buckets.
2. The user_data that mounts the EBS volume and installs docker

## The user data
We then have the `user_data` folder to run the setup on the ec2 instance.
Our output returns the ID of the ec2 instance that we can then ssh into via the ssm manager.  
Since we run through the Fn.Sub to substitute variables into the user_data script as needed, all non-substituted variables must use the `${!VAR}` syntax.

# CDK commands

## Create the env
```bash
python -m venv .env
```

## Activate the env
```bash
source .env/bin/activate
``` 

## Context parameters
This dev worker stack has the following optional context parameters.  
Context parameters are defined with the `-c "STACK_NAME=my-stack` argument.  
Repeat the `-c` parameter for defining multiple parameters.    
i.e 
```
cdk deploy -c "STACK_NAME=my-stack"
```

The list of possible context parameters and their descriptions are listed below:

### Optional context parameters
| **Context Key**      | **Description**                                                                                                                                                                | **Default Value**       |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------|
| STACK_NAME           | Unique Name of the stack you wish to deploy                                                                                                                                    | dev-worker-${USER}-uuid |
| EC2_TYPE             | Type of instance to be deployed, options can be seen here https://aws.amazon.com/ec2/instance-types/                                                                           | m4.4xlarge              |
| MACHINE_IMAGE        | AMI can be found here: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html#finding-an-ami-console                                                          | ami-0dc96254d5535925f   |
| VAR_VOLUME_SIZE      | /var is mounted on a separate EBS volume to stop 8 Gb root volume from filling up. Can also be used as a scratch space by setting TMPDIR to /var/tmp. Unit is Gb               | 16                      |
| EXTENDED_VOLUME_SIZE | /data/ is also mounted on a separate EBS volume/. Unit is Gb                                                                                                                   | 100                     |
| LAUNCH_TEMPLATE_NAME | If running a spot instance, this is the name of the launch template used                                                                                                       | dev_worker_template     |
| INSTANCE_NAME        | This is the name of the instance deployed and will show up in the EC2 console                                                                                                  | dev_worker_instance_cdk |
| USE_SPOT_INSTANCE    | Would you like to use a spot instance, much cheaper but cannot be stopped, only terminated and may be shutdown at any time or fail to launch if the MAX_SPOT_PRICE is too low. | True                    |
| MAX_SPOT_PRICE       | Maximum hourly rate of the spot instance in dollar value                                                                                                                       | 0.30                    |

## Validate the stack
```bash
cdk synth -c "STACK_NAME=alexis-unique-stack"
```

## Deploy the workflow with different parameters
You can change any of the parameters seen in the `cdk.json` *context* attribute
```bash
cdk diff -c "STACK_NAME=alexis-unique-stack" -c "EC2_TYPE=t2.micro"
cdk deploy -c "STACK_NAME=alexis-unique-stack" -c "EC2_TYPE=t2.micro"
```

Notes:
You will need to use this same STACK_NAME parameter when destroying the stack
i.e:
```cdk
cdk destroy -c "STACK_NAME=alexis-unique-stack"
```

## Some helpful commands
*These commands assume the following ssh configs have been set:*
This assumes you have loaded your public key `aws.pub` into your github keys (which are publicly accessible)
```
host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
    User ec2-user
    IdentityFile /path/to/private/key/.ssh/aws
```

### Sync iap credentials to instance
```
INSTANCE_ID="i-a1b2c3d4e5"
rsync --archive ~/.iap/ "${INSTANCE_ID}:/home/ec2-user/.iap/"
```

### Sync notebook to this instance
The jupyter notebook provided gives a set of useful functions specific to AWS.
This can allow the user to launch multiple cells in the evening, and have the instance stop after all cells have completed.
The stopped instance can then be restarted in the morning. Only non-spot instances may be stopped.
```
INSTANCE_ID="i-a1b2c3d4e5"
NOTEBOOK_NAME=dev_worker_notebook.ipynb
rsync --archive "${NOTEBOOK_NAME}" "${INSTANCE_ID}:/home/ec2-user/my-notebook.ipynb"
```

## Launching jupyter
ssh into the instance binding the port 8888 via the ec2-user  
and launch jupyter in the background
```bash
# Local
INSTANCE_ID="i-a1b2c3d4e5"
ssh -L8888:localhost:8888 "${INSTANCE_ID}"
# Remote
nohup jupyter notebook --port=8888 &
```

Then check the token using: 
```
cat nohup.out
```

And open up a browser tab of the notebook.