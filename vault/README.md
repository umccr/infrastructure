# Vault

This currently contains the codified configuration of the UMCCR's installation of Hashicorp Vault.


Use the `provision.sh` script to apply the Vault configuration defined in `./data`. It uses `curl` and the HTTP API of Vault to configure the server. It expects two environment variables to be set appropriately:
```
export VAULT_ADDR=<vault IP address>
export VAULT_TOKEN=<vault access token>
```

More details [here](https://www.hashicorp.com/blog/codifying-vault-policies-and-configuration).
