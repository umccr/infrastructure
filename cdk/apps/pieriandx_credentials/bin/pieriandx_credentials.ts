#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { PieriandxCredentialsStack } from '../lib/pieriandx_credentials-stack';
import {
    PIERIANDX_BASE_URL_DEV,
    PIERIANDX_INSTITUTION_DEV, PIERIANDX_API_KEYNAME,
    SECRETS_SSM_ROOT,
    SLACK_HOST_SSM_NAME,
    SLACK_WEBHOOK_SSM_NAME, PIERIANDX_JWT_KEYNAME, PIERIANDX_JWT_COLLECTION_FUNCTION_NAME
} from "../constants";

const app = new cdk.App();


const DEV_ACCOUNT_ID = "843407916570"
const DEV_ACCOUNT_REGION = "ap-southeast-2"

/* Development Stack */
new PieriandxCredentialsStack(app, 'PieriandxCredentialsStackDev', {
    pieriandx_base_url: PIERIANDX_BASE_URL_DEV,
    pieriandx_institution: PIERIANDX_INSTITUTION_DEV,
    api_key_name: PIERIANDX_API_KEYNAME,
    jwt_key_name: PIERIANDX_JWT_KEYNAME,
    key_ssm_root: SECRETS_SSM_ROOT,
    collect_function_name: PIERIANDX_JWT_COLLECTION_FUNCTION_NAME,
    slack_host_ssm_name: SLACK_HOST_SSM_NAME,
    slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
    env: {
        account: DEV_ACCOUNT_ID,
        region: DEV_ACCOUNT_REGION
    }
});

