
# Gen3 Admin VM

Deploy an ec2 instance to use as Gen3 admin VM

## Quick start:


1. Create the venv
`python3 -m venv venv`
2. Activate the venv
`source .env/bin/activate`
3. Install dependencies
`pip install -r requirements.txt`
4. Deploy the ec2 instance:
`cdk deploy`
5. Log into the instance:
`aws ssm start-session --target=<instance id>`
6. Shut down the instance and stack:
`cdk destroy`

## Observe the cdk.json
(see below)

## The user data

# CDK commands

## Create the env
```bash
python -m venv venv
```

## Activate the env
```bash
source .env/bin/activate
``` 

### Optional context parameters (cdk.json)
| **Context Key**      | **Description**                                                                                                                                                                | **Default Value**       |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------|
| EC2_TYPE             | Type of instance to be deployed, options can be seen here https://aws.amazon.com/ec2/instance-types/                                                                           | m4.4xlarge              |
| MACHINE_IMAGE        | AMI can be found here: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html#finding-an-ami-console                                                          | ami-0dc96254d5535925f   |
| EXTENDED_VOLUME_SIZE | /data/ is also mounted on a separate EBS volume/. Unit is Gb                                                                                                                   | 100                     |
| LAUNCH_TEMPLATE_NAME | If running a spot instance, this is the name of the launch template used                                                                                                       | dev_worker_template     |
| INSTANCE_NAME        | This is the name of the instance deployed and will show up in the EC2 console                                                                                                  | dev_worker_instance_cdk |
## Validate the stack
```bash
cdk synth
```

