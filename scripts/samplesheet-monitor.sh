#!/bin/bash
set -eo pipefail

TARGET_FILE="SampleSheet.csv"

# require env variable DEPLOY_ENV to be set
if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi

# if the value of DEPLOY_ENV is anything else than 'prod' we default to the development setup
if test "$DEPLOY_ENV" = "prod"; then
    DIR="/storage/shared/raw/Baymax"
else
    DIR="/storage/shared/dev/Baymax"
fi

inotifywait -m -r --exclude "[^c][^s][^v]$" $DIR -e create -e moved_to |
    while read path action file; do
        if test "$file" = "$TARGET_FILE"; then
          whoami
          echo "$DEPLOY_ENV"
          AWS_PROFILE=umccr_ops_admin_no_mfa /home/limsadmin/.miniconda3/bin/aws lambda invoke --invocation-type RequestResponse --function-name bootstrap_slack_lambda_dev --region ap-southeast-2 --payload "{ \"topic\": \"Incoming run monitor\", \"title\": \"New runfolder detected\", \"message\": \"$path\"}" /dev/null
        fi
    done