#!/bin/bash

set -o errexit
set -o verbose

# Install project dependencies
pip install -r requirements.txt -r requirements-dev.txt
