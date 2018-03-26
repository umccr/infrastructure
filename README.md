# infrastructure
Repo for the UMCCR compute infrastructure

NOTE: AWS access credentials are expected as the usual env variables.

## Packer
Packer configurations to build container/AMI images

Move into the desired AMI directory and execute the packer command.
`packer build <AMI's json config>`

### stackstorm-ami
Generate an Amazon EC2 AMI with our custom StackStorm setup

Inspiration taken from:
- https://programmaticponderings.com/2017/03/06/baking-aws-ami-with-new-docker-ce-using-packer/


## Terraform
Provision the AWS infrastructure for various bits of UMCCR infrastructure.

Stacks are kept separate from each other and each stack has it's own state. Move into the stacks directory to execute the terraform commands:
- `terraform init` to initialise the stack (load modules and setup the remote backend)
- `terraform plan` to see what terraform would change on your current state
- `terraform apply` to apply the proposed changes


### modules
Reusable Terraform modules that can be used across multiple stacks.

### stacks
Each stack has it's own Terraform state and usually corresponds to a logical unit, like a service or piece of infrastructure like StackStorm.

#### stackstorm
Provisions the infrastructure needed to run the StackStorm automation service. This includes customisations and configurations for UMCCR.

#### users
Provisions an automation user 'travis' that can be used to build our custom AMIs with packer.
