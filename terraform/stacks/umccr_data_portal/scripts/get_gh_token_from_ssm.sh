#!/bin/bash
set -e

# jq reads from stdin so we don't have to set up any inputs, but let's validate the outputs
eval "$(jq -r '@sh "export SSM_PARAM_NAME=\(.ssm_param_name)"')"
if [[ -z "${SSM_PARAM_NAME}" ]]; then export SSM_PARAM_NAME=none; fi

gh_token=$(aws ssm get-parameter --name "${SSM_PARAM_NAME}" --output text --query Parameter.Value --with-decryption)

echo "{\"gh_token\": \"$gh_token\"}"
