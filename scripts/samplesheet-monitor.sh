#!/bin/bash
set -eo pipefail

TARGET_FILE="SampleSheet.csv"
MONITORED_DIR_DEV="/storage/shared/dev/Baymax"
MONITORED_DIR_PROD="/storage/shared/raw/Baymax"
LAMBDA_DEV="bootstrap_slack_lambda_dev"
LAMBDA_PROD="bootstrap_slack_lambda_prod"


# require env variable DEPLOY_ENV to be set
if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi

# if the value of DEPLOY_ENV is anything else than 'prod' we default to the development setup
if test "$DEPLOY_ENV" = "prod"; then
    DIR="$MONITORED_DIR_PROD"
    LAMBDA="$LAMBDA_PROD"
else
    DIR="$MONITORED_DIR_DEV"
    LAMBDA="$LAMBDA_DEV"
fi

inotifywait -m -r --exclude "[^c][^s][^v]$" $DIR -e create -e moved_to |
    while read path action file; do
        if test "$file" = "$TARGET_FILE"; then
          whoami
          echo "$DEPLOY_ENV"
          source $HOME/.bashrc
          AWS_PROFILE=sample_monitor aws lambda invoke --invocation-type RequestResponse --function-name "$LAMBDA" --region ap-southeast-2 --payload "{ \"topic\": \"Incoming run monitor\", \"title\": \"New runfolder detected\", \"message\": \"$path\"}" /dev/null
        fi
    done