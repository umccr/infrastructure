# Vault

This currently contains the codified configuration of the UMCCR's installation of Hashicorp Vault.


Use the `provision.sh` script to apply the Vault configuration defined in `./data`. It uses `curl` and the HTTP API of Vault to configure the server. It expects two environment variables to be set appropriately:
```
export VAULT_ADDR=<vault URL:PORT>
export VAULT_TOKEN=<vault access token>
```
This requires that the executing user has sufficient permissions to apply those changes. This is usually done at the Vault initialisation stage and performed by a root user or user with similar permissions. Normal Vault users will not have sufficient privileges.

More details [here](https://www.hashicorp.com/blog/codifying-vault-policies-and-configuration).
