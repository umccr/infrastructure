# scripts

## vault-env-setup.sh

Current usage: use as after script hook to `assume-role`.

Setup:
- install `assume-role` as per [docs](https://github.com/coinbase/assume-role) (but use modified script version with AFTER_SCRIPT hook support from UMCCR [fork](https://github.com/umccr/assume-role))
- set env var to `vault-env-setup.sh`: `export AFTER_SCRIPT="/path/to/vault-env-setup.sh"`

Usage:
- set GitHub token: `export GITHUB_TOKEN=<your personal GitHub access token>`
- call `assume-role` as usual: `assume-role prod ops-admin`

The `assume-role` script will populate the env with AWS access credentials and the `vault-env-setup.sh` script will add Vault access credentials. You should now be able to use tools like Terraform that require access to AWS and Vault.
