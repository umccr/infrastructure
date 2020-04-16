
# Dev worker project

Deploy an ec2 instance with docker ready to go and logged into our ECR (Elastic container registry)

This repo is (partially) based on the cdk example provided [here](https://github.com/aws-samples/aws-cdk-examples/blob/master/python/existing-vpc-new-ec2-ebs-userdata/cdk_vpc_ec2)

## Quick start:

0. Define the following function on your `.bashrc` or equivalent:
```bash
ssm() {
    # ssh into the ec2 instance.
    # params: instance_id - should start with 'i-'
    instance_id="$1"
    aws ssm start-session --target "${instance_id}" \
                          --document-name "AWS-StartInteractiveCommand" \
                          --parameters command="sudo su - ssm-user"
}
```

1. Create the venv
`python3 -m venv .env`
2. Activate the venv
`source .env/bin/activate`
3. Deploy the ec2 instance:
`cdk deploy`
4. Log into the instance:
`ssm i-....`
5. Shut down the instance and stack:
*Assumes no other instances have been launched from this folder - verify STACK_NAME in context*
`cdk destroy`

## Observe the cdk.json
We have the following variables as default:
* EC2_TYPE: m5.4xlarge  # 16 CPU, 64 GB RAM
* MACHINE_IMAGE: ami-0dc96254d5535925f
* VOLUME_SIZE: "100"  # GB
    
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
cdk deploy -c "STACK_NAME=my-stack" -c "USE_SPOT_INSTANCE=false"
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
| MAX_SPOT_PRICE       | Maximum hourly rate of the spot instance in dollar value                                                                                                                       | null                    |
| CREATOR              | Name of the creator                                                                                                                                                            | null                    |
## Validate the stack
```bash
cdk synth
```

## Deploy the workflow with different parameters
You can change any of the parameters seen in the `cdk.json` *context* attribute
```bash
cdk diff -c "STACK_NAME=alexis-unique-stack" -c "EC2_TYPE=t2.micro"
cdk deploy -c "STACK_NAME=alexis-unique-stack" -c "EC2_TYPE=t2.micro"
```

## Terminating an instance / Destroying a stack.
Check the context file (`cdk.json`) and ensure the STACK_NAME is that of the one you wish to destroy.
If not, you will need to specify the STACK_NAME parameter when destroying the stack.
i.e:
```cdk
cdk destroy -c "STACK_NAME=alexis-unique-stack"
```

## Some helpful commands

### Set SSH config
This assumes you have loaded your public key complement `aws.pub` into your github keys (which are publicly accessible)
You may choose between ec2-user and ssm-user, both have identical setups. I would recommend the ssm-user.
*The ec2-user may be removed in the near future if all the ssm functionality works correctly*
You will need to use the ssh command over ssm if you wish to rsync data from your local machine to the instance.  
Note that data transfer is very slow as we're not going over port 22 directly.
```
host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
    User ssm-user
    IdentityFile /path/to/private/key/.ssh/aws
```

### Setting port forwarding through SSM

Set up the following shell function in your `~.bashrc`.
```
# Start aws session
ssm_port() {
  # Log into an ec2 instance and forward the ports
  # param: instance_id: starts with 'i-'
  # param: remote_port: port on ec2 you wish to forward - should be a number
  # param: local_port (optional): port on ec2 you wish to bind the remote port to.
  instance_id="$1"
  remote_port="$2"
  local_port="$3"
  # If local port is not set, set as remote port
  if [[ -z "${local_port}" ]]; then
    local_port="${remote_port}"
  fi
  # Run port forwarding command
  aws ssm start-session --target "${instance_id}" \
                        --document-name "AWS-StartPortForwardingSession" \
                        --parameters "{\"portNumber\":[\"${remote_port}\"],\"localPortNumber\":[\"${local_port}\"]}"
}
```


### Sync iap credentials to instance
```
INSTANCE_ID="i-a1b2c3d4e5"
rsync --archive "~/.iap/" "${INSTANCE_ID}:/home/ssm-user/.iap/"
```

### Sync notebook to this instance
The jupyter notebook provided gives a set of useful functions specific to AWS.
This can allow the user to launch multiple cells in the evening, and have the instance stop after all cells have completed.
The stopped instance can then be restarted in the morning. Only non-spot instances may be stopped.
```
INSTANCE_ID="i-a1b2c3d4e5"
NOTEBOOK_NAME=dev_worker_notebook.ipynb
rsync --archive "${NOTEBOOK_NAME}" "${INSTANCE_ID}:/home/ssm-user/my-notebook.ipynb"
```

## Launching jupyter
ssh into the instance binding the port 8888 via the ssm-user  
and launch jupyter in the background
```bash
# Local
INSTANCE_ID="i-a1b2c3d4e5"
# Via SSM
ssm_port "${INSTANCE_ID}" 8888
# Via SSH
ssh -L8888:localhost:8888 "${INSTANCE_ID}"
# Remote (run ssm)
nohup jupyter notebook --port=8888 &
```

Then check the token using: 
```
cat nohup.out
```

And open up a browser tab of the notebook.

### Jupyter extensions.
The following extensions are enabled by default:
* Freeze
  * Prevent you accidentally re-running a specific code-block.
* Toc2
  * Nicely places the table of contents for the notebook on the left hand side of the page.
* Execute time
  * Displays last execution time and duration for each cell block

## Troubleshooting

### Expired Token Exception
> An error occurred (ExpiredTokenException) when calling the StartSession operation: The security token included in the request is expired
ssh_exchange_identification: Connection closed by remote host

This means you need to re-login to aws via the google TFA authentication.

### Target not connected
> An error occurred (TargetNotConnected) when calling the StartSession operation: i-07aa0098c62dc5001 is not connected.
ssh_exchange_identification: Connection closed by remote host

The instance takes time to load up, it may not be at the stage that it's ready to accept logins or is yet to populate the authorized keys.

### Session timed out immediately whilst trying to run a notebook
>Session: alexis.lucattini@umccr.org-0093f9ff6b4505b52 timed out

This will happen if there's no activity on the port. You need to start the notebook first and then log in.