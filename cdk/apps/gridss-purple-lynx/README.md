
# Gridss container project

Deploy an ec2 instance with our gridss-purple-lynx container.

This repo is based on the cdk example provided [here](https://github.com/aws-samples/aws-cdk-examples/blob/master/python/existing-vpc-new-ec2-ebs-userdata/cdk_vpc_ec2)


## Observe the cdk.json
We have the following variables as default:
* EC2_TYPE: m4.4xlarge
* KEY_NAME: alexis-dev
* MACHINE_IMAGE: ami-0dc96254d5535925f
* VOLUME: 
    * SIZE: "100"
    * MOUNT_POINT": /dev/xvdh

    
## Setup the stack
There are two main things under the stack script that  
are characteristic to this workflow 
1. Policies to allow pulling of containers from our ECR and S3 buckets.
2. The user_data that mounts the EBS volume and installs docker

## Install and run a gridss test on the ec2 instance
We then have the `user_data` folder to run the setup on the ec2 instance.
Our output returns a public IP of our ec2 instance that we can then ssh into via the ssm manager.  
We must be careful to remember that the user_data may be continuing to run in the background in the interim.

# CDK commands

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
cdk diff -c "KEY_NAME=myname-dev' 
cdk deploy -c "KEY_NAME=myname-dev' 
```