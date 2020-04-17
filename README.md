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
      - [Scripts](#scripts)
      - [scripts](#scripts)
      - [terraform](#terraform)
            - [modules](#modules)
            - [stacks](#stacks)
                  - [bastion](#bastion)
                  - [bootstrap](#bootstrap)

# infrastructure

Repo for the UMCCR compute infrastructure as code.

We are making all our infrastructure code public based on referents like [18F](https://github.com/18F), [Fedora Infra](https://infrastructure.fedoraproject.org/cgit/ansible.git/tree/) and other opensource projects.  **Public funding, public code.**

If you found some sensitive material such as keys, certificates that might been exposed by accident, please report to **services at umccr dot org** ASAP.

**NOTE**: This repository contains GIT submodules.
The submodules refer to a specific commit in the external repo and therefore you may not get the latest version of the code.

You may want to clone it with: `git clone --recurse-submodules https://github.com/umccr/infrastructure.git`


## docker
Convenience containers

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

Terraform requires AWS credentials to manipulate AWS resources. For more details please refer to the [wiki](https://github.com/umccr/wiki/blob/master/computing/cloud/aws.md#aws-command-line-interface).

### modules
Reusable Terraform modules that can be used across multiple stacks. If you want to create a new module, use the `skel` module as a template.


### stacks
A Terraform stack usually corresponds to a logical unit, like a piece of infrastructure for a service. We use a central S3 bucket in our AWS `bastion` account to keep all Terraform state and we use DynamoDB tables in each account to enable state locking.

#### bastion
See [README](terraform/stacks/bastion/README.md)


#### bootstrap
See [README](terraform/stacks/bootstrap/README.md)
