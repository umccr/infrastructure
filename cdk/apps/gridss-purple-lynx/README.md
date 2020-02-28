
# Gridss container project

Deploy an ec2 instance with our gridss-purple-lynx container.

This repo is based on the cdk example provided [here](https://github.com/aws-samples/aws-cdk-examples/blob/master/python/existing-vpc-new-ec2-ebs-userdata/cdk_vpc_ec2)


## Setup the stack
There are four main variables to set up under the stack script that  
are characteristic to this workflow 
1. The VPC used by the instance - this is set as our dev account VPC by default.  
2. The EC2 type used to run the script.
3. Policies to allow pulling of containers from our ECR and S3 buckets.
4. Configure additional volumes (EBS) to launch

## Install and run a gridss test on the ec2 instance
We then have the `userdata` folder to run the setup on the ec2 instance.
Our output returns a public IP of our ec2 instance that we can then ssh into via the ssm manager.  
We must be careful to remember that the user_data may be continuing to run in the background in the interim.