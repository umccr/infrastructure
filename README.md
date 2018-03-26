# infrastructure
Repo for the UMCCR compute infrastructure


## Packer
Packer configurations to build container/AMI images

### stackstorm-ami
Generate an Amazon EC2 AMI with our custom StackStorm setup

Inspiration taken from:
- https://programmaticponderings.com/2017/03/06/baking-aws-ami-with-new-docker-ce-using-packer/


## Terraform
Provision the AWS infrastructure for various bits of UMCCR infrastructure.


### modules
Reusable Terraform modules that can be used across multiple stacks.

### stacks
Each stack has it's own Terraform state and usually corresponds to a logical unit, like a service or piece of infrastructure like StackStorm.

#### stackstorm
Provisions the infrastructure needed to run the StackStorm automation service. This includes customisations and configurations for UMCCR.

#### users
Provisions an automation user 'travis' that can be used to build our custom AMIs with packer.
