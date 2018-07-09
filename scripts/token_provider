#!/bin/bash
set -e
set -o pipefail

################################################################################
# Script to generate and inject Vault tokens into Travis build configurations  #
# to enable the build to retrieve secrets from vault dynamically.              #
################################################################################

# This script expects the following env variables:
# - VAULT_ADDR: the address of the local Vault = base URL to use for API calls
# - VAULT_USER: the user to log into the vault
# - VAULT_PASS: the password for the user login

# function to check if an element is contained in an array
elementIn () {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}


################################################################################
# - log into Vault
# - generate access token
# - find all GitHub repos that have Travis enabled
# - for each repo check if it carries the 'umccr-automation' topic
# - if yes, inject Vault access token into Travis env vars


vault_operator_token=$(vault login -no-store -token-only -method=userpass username=$VAULT_USER password=$VAULT_PASS)
vault_token=$(VAULT_TOKEN=$vault_operator_token vault token create -policy=aws-sts-ops_admin_no_mfa-update -policy=kv-datadog-read -ttl=30s -format=json | jq -r '.auth.client_token')

# retrieve the TRAVIS_TOKEN from vault to make authenticated requests against the Travis API
travis_token=$(VAULT_TOKEN=$vault_operator_token vault kv get -format=json  kv/travis | jq -r '.data.api_token')

repo_slugs=($(curl -sS -H "Travis-API-Version: 3" -H "Authorization: token $travis_token"  'https://api.travis-ci.org/repos?limit=50&active=true&sort_by=name' | jq -r '.repositories | .[] | .slug'))

for repo_slug in "${repo_slugs[@]}"; do 
    # We use the API unauthenticated and thet has tight usage limits! It that becomes an issue we could
    # use authenticated API requests with -H "Authorization: token $GITHUB_TOKEN" to increase these limits
    topics=($(curl -sS -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.mercy-preview+json" https://api.github.com/repos/$repo_slug/topics | jq -r '.names | .[]?'))
    if [ ${#topics[@]} -eq 0 ]; then
        echo "Ignoring repo without topics: $repo_slug"
        continue;
    fi 
    if elementIn "umccr-automation" "${topics[@]}"; then 
        echo "Found repo to inject ENV: $repo_slug"
        repo_slug_enc="${repo_slug/\//%2F}"

        # Can't overwrite existing vars, therefore we have to find the IDs for the vars we want to update
        env_vars_json=$(curl -sS -H "Travis-API-Version: 3" -H "Authorization: token $travis_token" https://api.travis-ci.org/repo/$repo_slug_enc/env_vars)
        vault_addr_id=$(echo $env_vars_json | jq -r '.env_vars | .[] | select( .name | contains("VAULT_ADDR")) | .id')
        vault_token_id=$(echo $env_vars_json | jq -r '.env_vars | .[] | select( .name | contains("VAULT_TOKEN")) | .id')

        # if the retrieved values are empty, this may be a new repo, which is not set up for Vault yet
        # requests to update a non-existing var will fail, we have to create new vars instead
        if test -z "$vault_addr_id"; then
            echo "VAULT_ADDR not set on repo marked as 'umccr-automation'! Creating new one."
            echo "curl -X POST -H \"Content-Type: application/json\" -H \"Travis-API-Version: 3\" -H \"Authorization: token $travis_token\" -d '{ \"env_var.name\": \"VAULT_ADDR\", \"env_var.value\": \"$VAULT_ADDR\", \"env_var.public\": false }' https://api.travis-ci.org/repo/$repo_slug_enc/env_vars"
        else
            echo "curl -X Patch -H \"Content-Type: application/json\" -H \"Travis-API-Version: 3\" -H \"Authorization: token $travis_token\" -d '{ \"env_var.value\": \"$VAULT_ADDR\", \"env_var.public\": false }' https://api.travis-ci.org/repo/$repo_slug_enc/env_var/$vault_addr_id"
        fi
        if test -z "$vault_token_id"; then
            echo "VAULT_TOKEN not set on repo marked as 'umccr-automation'! Creating new one."
            echo "curl -X POST -H \"Content-Type: application/json\" -H \"Travis-API-Version: 3\" -H \"Authorization: token $travis_token\" -d '{ \"env_var.name\": \"VAULT_TOKEN\", \"env_var.value\": \"$vault_token\", \"env_var.public\": false }' https://api.travis-ci.org/repo/$repo_slug_enc/env_vars"
        else
            echo "curl -X Patch -H \"Content-Type: application/json\" -H \"Travis-API-Version: 3\" -H \"Authorization: token $travis_token\" -d '{ \"env_var.value\": \"$vault_token\", \"env_var.public\": false }' https://api.travis-ci.org/repo/$repo_slug_enc/env_var/$vault_token_id"
        fi
    else 
        echo "Ignoring repo that doesn't carry the 'umccr-automation' topic: $repo_slug"
    fi
done

