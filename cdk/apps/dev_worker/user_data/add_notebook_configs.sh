#!/usr/bin/env bash

# Fail if any command fails
set -e

# Set vars
# FIXME use original repo as remote origin
GIT_REMOTE="https://github.com/alexiswl/umccr-infrastructure"
# FIXME use the master branch
GIT_BRANCH="dev_worker_cdk"

# Create nbconfig directory
mkdir -p $HOME/.jupyter_notebook_configs
mkdir -p $HOME/.jupyter

(
 # Change to this directory
 cd $HOME/.jupyter_notebook_configs
 # Initialise through git
 git init
 # Add remotecd
 git remote add origin -f "${GIT_REMOTE}"
 # Add notebook configs to sparse checkout
 echo "cdk/apps/dev_worker/user_data/notebook_configs" >> ".git/info/sparse-checkout"
 # Use a sparse checkout
 git config core.sparseCheckout true
 # Pull from origin
 git pull origin "${GIT_BRANCH}"
)

# Link data from notebook configs to jupyter config folder
ln -s "$HOME/.jupyter_notebook_configs/cdk/apps/dev_worker/user_data/notebook_configs" "$HOME/.jupyter/nbconfig"