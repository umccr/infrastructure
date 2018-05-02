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
            * [bootstrap](#bootstrap)
            * [packer](#packer-2)
            * [stackstorm](#stackstorm)

# infrastructure
Repo for the UMCCR compute infrastructure as code

**NOTE**: contains GIT submodules, so you may want to check it out with:  
`git clone --recurse-submodules https://github.com/umccr/infrastructure.git`


## Docker
Convenience containers

### Packer
Container to run packer.
See [README](docker/packer/README.md) on how to build and use it.

## Packer
Packer configurations to build container/AMI images
Inspiration taken from:
- https://programmaticponderings.com/2017/03/06/baking-aws-ami-with-new-docker-ce-using-packer/

Packer requires sufficient AWS credentials which can be obtained assuming the `ops-admin` role:  
`assume-role dev ops-admin`

```
packer build <ami.json>
```
**NOTE**: Packer can also be run using a docker container (see above).


### stackstorm-ami
**NOTE**: this is a GIT submodule

See the stackstorm-ami [README](packer/stackstorm-ami/README.md)


## Terraform
UMCCR infrastructure as code

We use `modules` for reusable components and live `stacks` that are applied to generate the actual infrastructure.

The recommended Terraform workflow consists of the following commands:

- `terraform init` to initialise the stack (optional; use on first use or after configuration change).
- `terraform workspace select dev` to select a workspace (optional; use for stacks that use workspaces).
- `terraform plan -out=change.tfplan` to see what Terraform would change on the current state and to write the changes to a file.
- `terraform show change.tfplan` to review the proposed changes.
- `terraform apply change.tfplan` to apply the reviewed changes if acceptable.

More details with `terraform help`.

Terraform requires AWS credentials to manipulate AWS resources. It uses the usual AWS supported methods to retrieve them, i.e. env variables or AWS profiles. If not stated otherwise, all stacks require ops-admin credentials, which can be obtained assuming the `ops-admin` role.
For more details please refer to the `assume-role` script.


### modules
Reusable Terraform modules that can be used across multiple stacks.


### stacks
A Terraform stack usually corresponds to a logical unit, like a piece of infrastructure for a service like StackStorm. We use a central S3 bucket in our AWS `bastion` account to keep all Terraform state and we use DynamoDB tables in each account to enable state locking.


#### bastion
See [README](terraform/stacks/bastion/README.md)


#### bootstrap
See [README](terraform/stacks/bootstrap/README.md)


#### packer
See [README](terraform/stacks/packer/README.md)


#### stackstorm
See [README](terraform/stacks/stackstorm/README.md)
