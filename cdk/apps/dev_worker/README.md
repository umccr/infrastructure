
# Dev worker project

Deploy an ec2 instance with docker ready to go and logged into our ECR (Elastic container registry)

This repo is (partially) based on the cdk example provided [here](https://github.com/aws-samples/aws-cdk-examples/blob/master/python/existing-vpc-new-ec2-ebs-userdata/cdk_vpc_ec2)


## Observe the cdk.json
We have the following variables as default:
* EC2_TYPE: m4.4xlarge
* KEY_NAME: alexis-dev
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
Our output returns a public IP of our ec2 instance that we can then ssh into via the ssm manager.  
Since we run through the Fn.Sub to substitute variables into the user_data script as needed, all non-substituted variables must use the `${!VAR}` syntax.

# CDK commands

## Create the env
```bash
cdk init --language=python
```

## Activate the env
```bash
source .env/bin/activate
``` 

## Validate the stack
```bash
cdk synth
```

## Deploy the workflow
```bash
cdk deploy
```

## Deploy the workflow with different parameters
You can change any of the parameters seen in the `cdk.json` *context* attribute
```bash
cdk diff -c "STACK_NAME=alexis-unique-instance" -c "KEY_NAME=myname-dev' -c "EC2_TYPE=t2.micro"
cdk deploy -c "STACK_NAME=alexis-unique-instance" "KEY_NAME=myname-dev' -c "EC2_TYPE=t2.micro"
```