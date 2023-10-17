#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { Icav2CredentialsStack } from '../lib/icav2_credentials-stack';

const app = new cdk.App();

const CDK_APP_NAME = "icav2-credentials"
const ICAV2_BASE_URL = "https://ica.illumina.com/ica/rest"
const SLACK_HOST_SSM_NAME = "/slack/webhook/host"
const SLACK_WEBHOOK_SSM_NAME = "/slack/webhook/id"

const LOCAL_REGION = "ap-southeast-2"
const DEFAULT_REGION = "ap-southeast-2"
const LOCALSTACK_ACCOUNT_ID  = "000000000000"
const DEVELOPMENT_ACCOUNT_ID = "843407916570"

new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-test-workflow-deployment-role-localstack`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: "umccr-test-workflow-deployment-localstack",
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [
            "umccr/cwl-ica"
        ],
        github_role_name: "workflow-deployment-localstack",
        env: {
            account: LOCALSTACK_ACCOUNT_ID,
            region: LOCAL_REGION
        },

    }
);

new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-umccr-test-pipelines-dev`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: `${CDK_APP_NAME}-umccr-test-pipelines`,
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [
            "umccr/cwl-ica"
        ],
        github_role_name: `${CDK_APP_NAME}-umccr-test-pipelines-deployment-role`,
        env: {
            account: DEVELOPMENT_ACCOUNT_ID,
            region: DEFAULT_REGION
        },
    }
);

new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-umccr-test-staging-dev`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: `${CDK_APP_NAME}-umccr-test-staging`,
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [],
        github_role_name: null,
        env: {
            account: DEVELOPMENT_ACCOUNT_ID,
            region: DEFAULT_REGION
        },
    }
);

new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-umccr-test-production-dev`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: `${CDK_APP_NAME}-umccr-test-production`,
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [],
        github_role_name: null,
        env: {
            account: DEVELOPMENT_ACCOUNT_ID,
            region: DEFAULT_REGION
        },
    }
);
