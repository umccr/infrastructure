#!/bin/bash

after_script(){
  echo "name: $AWS_ACCOUNT_NAME"
  # build the Vault server address based on the AWS account name
  if [ ! $AWS_ACCOUNT_NAME = "" ]; then
    echo "Using AWS account: $AWS_ACCOUNT_NAME"
  else
    echo "Could not find AWS account name. Make sure you called assume-role."
    return
  fi


  if [ $AWS_ACCOUNT_NAME = "prod" ]; then
    export VAULT_ADDR='https://vault.prod.umccr.org:8200'
  elif [ $AWS_ACCOUNT_NAME = "dev" ]; then
    export VAULT_ADDR='https://vault.dev.umccr.org:8200'
  else
    echo "Unrecognised or unset AWS account name. Could not create Vault server address."
    return
  fi

  # check if there is already a Vault token
  if [ ! $VAULT_TOKEN = "" ]; then
    echo "Found a Vault token, trying to renew it..."
    vault token renew $VAULT_TOKEN
    if [ $? == 0 ]; then
      echo "Renewal successful." # or at least no error, so we stop here
      return
    fi
    # if the renewal was unsuccessful, we attempt to create a new one
    echo "Renewal unsuccessful. Trying to request a new token..."
  fi

  # if GITHUB_TOKEN is not set, it will ask for it
  echo "Attempting a Vault login"
  vault login -method=github token=$GITHUB_TOKEN
  if [ $? != 0 ]; then
    echo "ERROR logging into Vault."
    return
  fi

  echo "Requesting Vault access token..."
  vault_token=$(vault token create -explicit-max-ttl=30m -period=10m --format=json | jq -r .auth.client_token)
  if [ $vault_token = "" ]; then
    echo "ERROR requesting Vault token"
  fi
  echo "Token: $vault_token"
  # eval $(echo export VAULT_TOKEN="$vault_token")
  export VAULT_TOKEN="$vault_token"
  echo "Vault access token successful retrieved. Session envars exported."
}

after_script;
