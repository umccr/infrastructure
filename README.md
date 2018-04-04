[![Build Status](https://travis-ci.org/umccr/infrastructure.svg?branch=master)](https://travis-ci.org/umccr/infrastructure)

Table of Contents
=================

   * [infrastructure](#infrastructure)
      * [Docker](#docker)
         * [Packer](#packer)
      * [Packer](#packer-1)
         * [stackstorm-ami](#stackstorm-ami)
      * [Terraform](#terraform)
         * [modules](#modules)
         * [stacks](#stacks)
            * [bastion](#bastion)
            * [stackstorm](#stackstorm)
            * [packer](#packer-2)

# infrastructure
Repo for the UMCCR compute infrastructure

**NOTE**: contains GIT submodules, so you may want to check it out with:  
`git clone --recurse-submodules https://github.com/umccr/infrastructure.git`


## Docker
Convenience containers

### Packer
Container to run packer.
See README on how to build

## Packer
Packer configurations to build container/AMI images
Inspiration taken from:
- https://programmaticponderings.com/2017/03/06/baking-aws-ami-with-new-docker-ce-using-packer/

Packer requires sufficient AWS credentials which can be obtained assuming the `ops-admin` role:  
`assume-role prod ops-admin <mfa-token>`

```
packer build <ami.json>
```
**NOTE**: Packer can also be run using a docker container (see README in [docker/packer](docker/packer/README.md))


### stackstorm-ami
**NOTE**: this is a GIT submodule

Generate an Amazon EC2 AMI with our custom StackStorm setup  
`packer build stackstorm.json`


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

#### bastion
Provisions users, groups and assume policies to work with our other AWS accounts.

Note: the terraform state backend can be configured to use a custom AWS profile for access:
`terraform init -backend-config="profile=bastion"`
As this terraform stack requires access to our bastion account `terraform` commands do not rely on the default AWS credentials, but will ask for a profile name. This may change if/when a ops-admin role has been created in the bastion account.

#### stackstorm
Provisions the infrastructure needed to run the StackStorm automation service. This includes customisations and configurations for UMCCR.

#### packer
Provisions resources used to build our custom AMIs with packer.
