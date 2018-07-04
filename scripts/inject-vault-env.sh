#!/bin/bash
set -e
set -o pipefail

vault_addr="${1:-https://vault.dev.umccr.org:8200}"
vault_token="${2:-invalid}"

################################################################################
# script to inject env vars to enable Travis builds to fetch secrets from Vault:
# - find all GitHub repos that have Travis enabled
# - for each check if it carries the 'umccr-automation' topic
# - if yes, inject Vault env variables for Vault access

elementIn () {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

repo_slugs=($(curl -sS -H "Travis-API-Version: 3" -H "Authorization: token $TRAVIS_TOKEN"  'https://api.travis-ci.org/repos?limit=50&active=true&sort_by=name' | jq -r '.repositories | .[] | .slug'))

for repo_slug in "${repo_slugs[@]}"; do 
    topics=($(curl -sS -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.mercy-preview+json" https://api.github.com/repos/$repo_slug/topics | jq -r '.names | .[]?'))
    if [ ${#topics[@]} -eq 0 ]; then
        echo "Ignoring repo without topics: $repo_slug"
        continue;
    fi 
    if elementIn "umccr-automation" "${topics[@]}"; then 
        echo "Found repo to inject ENV: $repo_slug"
        repo_slug_enc="${repo_slug/\//%2F}"
        echo "Injecting VAULT_ADDR and VAULT_TOKEN into Travis for repo $repo_slug"
        curl -X POST -H "Content-Type: application/json" -H "Travis-API-Version: 3" -H "User-Agent: API Explorer" -H "Authorization: token $TRAVIS_TOKEN" -d '{ "env_var.name": "VAULT_ADDR", "env_var.value": "$vault_addr", "env_var.public": false }' https://api.travis-ci.org/repo/$repo_slug_enc/env_vars
        curl -X POST -H "Content-Type: application/json" -H "Travis-API-Version: 3" -H "User-Agent: API Explorer" -H "Authorization: token $TRAVIS_TOKEN" -d '{ "env_var.name": "VAULT_TOKEN", "env_var.value": "$vault_token", "env_var.public": false }' https://api.travis-ci.org/repo/$repo_slug_enc/env_vars
    else 
        echo "Ignoring repo that doesn't carry the 'umccr-automation' topic: $repo_slug"
    fi
done

