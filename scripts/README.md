# scripts

## assume-role-vault
Wrapper script around `assume-role` to setup Vault access in addition to the AWS credentials setup.

Setup:
- install `assume-role` as per [docs](https://github.com/coinbase/assume-role) including the addition to your `rc` file
- place `assume-role-vault` wrapper script somewhere
- add a bash alias: `alias assume-role-vault='. /path/to/assume-role-vault'` (Note: include the full path to the script to avoid recursion)

Usage:
- set GitHub token: `export GITHUB_TOKEN=<your personal GitHub access token>`
- call `assume-role-vault` the same as you would `assume-role` itself: `assume-role-vault prod ops-admin`

The `assume-role` script will populate the env with AWS access credentials and the `assume-role-vault` wrapper will add Vault access credentials. You should then be able to query Vault and use tools like Terraform that require access to AWS and Vault.

## safe-terraform
Wrapper to call `terraform` commands that checks the current environment. It compares the `git` branch, the `terraform.workspace` and the `AWS` account name to avoid accidental cross account deployments.

Usage:
- put the script on your `$PATH`
- use `safe-terraform` instead of `terraform`

## bash-utils.sh
XXX
