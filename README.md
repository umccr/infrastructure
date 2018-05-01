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

Stacks are kept separate from each other and each stack has it's own state. Move into the stacks directory to execute the Terraform commands:
- `terraform init` to initialise the stack (load modules and setup the remote backend) on first use or config changes
- `terraform plan` to see what Terraform would change on the current state
- `terraform apply` to apply the proposed changes

More details with `terraform help`.

Terraform requires AWS credentials to manipulate AWS resources. It uses the usual AWS supported methods to retrieve them, i.e. env variables or AWS profiles. If not stated otherwise, all stacks require ops-admin credentials, which can be obtained assuming the `ops-admin` role.
For more details please refer to the `assume-role` setup.

### modules
Reusable Terraform modules that can be used across multiple stacks. If you want to create a new module, use the `skel` module as a template.

### stacks
Each stack has it's own Terraform state and usually corresponds to a logical unit, like a service or piece of infrastructure like StackStorm.

Use the `skel` stack as a template if you wish to create a new one from scratch.

#### bastion
Provisions global users, groups and assume policies specific to the AWS `bastion` account.

**Note**: This stack can only be run by AWS admin users of the AWS `bastion` account.

If your default credentials (either env vars or default profile) are not from a `bastion` admin account, you have to set them. Either set the AWS env vars with your credentials or set an env variable defining the AWS profile to use.
`export AWS_PROFILE=<your bastion admin profile>`


#### stackstorm
Provisions the infrastructure needed to run the StackStorm automation service. This includes customisations and configurations for UMCCR.

**NOTE**: This stack can be applied equally against the `prod` AND the `dev` account and the Terraform state for each is kept separate in account specific S3 buckets. This means to operate on the stack Terraform has to be initialised against the correct account/bucket. To make sure you are working on the correct account/bucket remove the existing Terraform config and initialise with the account specific bucket (after `assume-role` into the account specific role):  
```
rm -rf .terraform
terraform init -backend-config="bucket=umccr-terraform-${AWS_ACCOUNT_NAME}"
```



#### packer
Provisions resources used by Packer to build custom AWS AMIs.

**NOTE**: Currently set up against the `prod` account only, but this should change.
This *should* only be applied against the `dev` account to limit any potential impact on production resources.

**NOTE**: This is used by Travis to automatically build new AMIs based on GitHub commits. If these resources are revoked or changed it may affect these Travis builds.
