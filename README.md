[![Build Status](https://travis-ci.org/umccr/infrastructure.svg?branch=master)](https://travis-ci.org/umccr/infrastructure)

Table of Contents
=================

- [Table of Contents](#table-of-contents)
- [infrastructure](#infrastructure)
      - [docker](#docker)
            - [packer](#packer)
      - [packer](#packer)
            - [pcgr-ami](#pcgr-ami)
            - [pcgr-ami](#pcgr-ami)
            - [stackstorm-ami](#stackstorm-ami)
            - [vault-ami](#vault-ami)
      - [Scripts](#scripts)
      - [scripts](#scripts)
      - [terraform](#terraform)
            - [modules](#modules)
            - [stacks](#stacks)
                  - [bastion](#bastion)
                  - [bootstrap](#bootstrap)
                  - [packer](#packer)
                  - [pcgr](#pcgr)
                  - [stackstorm](#stackstorm)
      - [vault](#vault)

# infrastructure
Repo for the UMCCR compute infrastructure as code

**NOTE**: contains GIT submodules.
The submodules refer to a specific commit in the external repo and therefore you may not get the latest version of the code.

You may want to clone it with:  
`git clone --recurse-submodules https://github.com/umccr/infrastructure.git`


## docker
Convenience containers

### packer
Container to run packer.
See [README](docker/packer/README.md) on how to build and use it.

## packer
Packer configurations to build container/AMI images
Inspiration taken from:
- https://programmaticponderings.com/2017/03/06/baking-aws-ami-with-new-docker-ce-using-packer/

To build AWS AMIs Packer requires sufficient AWS credentials which can be obtained assuming the `ops-admin` role:  
`assume-role dev ops-admin`

```
packer build <ami.json>
```
**NOTE**: Packer can also be run using a docker container (see the [README](docker/packer/README.md)).


### pcgr-ami
**NOTE**: this is a GIT submodule and therefore may be out of sync with [umccr/pcgr-ami](https://github.com/umccr/pcgr-ami)

See the README in packer/pcgr-ami

### pcgr-ami
**NOTE**: this is a GIT submodule

See the README in packer/pcgr-ami

### stackstorm-ami
**NOTE**: this is a GIT submodule and therefore may be out of sync with [umccr/stackstorm-ami](https://github.com/umccr/stackstorm-ami)

See the README in packer/stackstorm-ami

### vault-ami
**NOTE**: this is a GIT submodule and therefore may be out of sync with [umccr/vault-ami](https://github.com/umccr/vault-ami)

See the README in packer/vault-ami


## Scripts
Convenience scripts to assist in the setup/management of the infrastructure.

See the [README](scripts/README.md)

## scripts
Convenience scripts to help with the management of the infrastructure.

See this [README](scripts/README.md) for more details.


## terraform
UMCCR infrastructure as code

We use `modules` for reusable components and live `stacks` that are applied to generate the actual infrastructure.

The recommended Terraform workflow consists of the following commands:

- `terraform init` to initialise the stack (optional; use on first use or after configuration change).
- `terraform workspace list` to see which workspace you are currently on.
- `terraform workspace select dev` to select a workspace (optional; use for stacks that use workspaces).
- `terraform plan -out=change.tfplan` to see what Terraform would change on the current state and to write the changes to a file.
- `terraform show change.tfplan` to review the proposed changes.
- `terraform apply change.tfplan` to apply the reviewed changes if acceptable.

More details with `terraform help`.

Terraform requires AWS credentials to manipulate AWS resources. It uses the usual AWS supported methods to retrieve them, i.e. env variables or AWS profiles. If not stated otherwise, all stacks require ops-admin credentials, which can be obtained assuming the `ops-admin` role.
For more details please refer to the `assume-role` script [documentation](https://github.com/coinbase/assume-role).

Some Terraform stacks require access to sensitive data. We store those secrets in [Vault](https://www.vaultproject.io). Use the `assume-role-vault` wrapper script for convenience, more details [here](scripts/README.md).

### modules
Reusable Terraform modules that can be used across multiple stacks. If you want to create a new module, use the `skel` module as a template.


### stacks
A Terraform stack usually corresponds to a logical unit, like a piece of infrastructure for a service like StackStorm. We use a central S3 bucket in our AWS `bastion` account to keep all Terraform state and we use DynamoDB tables in each account to enable state locking.

#### bastion
See [README](terraform/stacks/bastion/README.md)


#### bootstrap
See [README](terraform/stacks/bootstrap/README.md)


#### packer
See [README](terraform/stacks/packer/README.md)


#### pcgr
See [README](terraform/stacks/pcgr/README.md)


#### stackstorm
See [README](terraform/stacks/stackstorm/README.md)

## vault
The UMCCR is using HashiCorp's Vault to store secrets. Here we keep the codified configuration of the UMCCR Vault setup. See the [README](vault/README.md) for more details.
