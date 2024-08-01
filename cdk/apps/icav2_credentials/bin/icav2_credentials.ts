#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { Icav2CredentialsStack } from '../lib/icav2_credentials-stack';

const app = new cdk.App();

const CDK_APP_NAME = "icav2-credentials"
const ICAV2_BASE_URL = "https://ica.illumina.com/ica/rest"

export const GITHUB_DOMAIN = 'token.actions.githubusercontent.com'

const SLACK_HOST_SSM_NAME = "/slack/webhook/host"
const SLACK_WEBHOOK_SSM_NAME = "/slack/webhook/id"

const LOCAL_REGION = "ap-southeast-2"
const DEFAULT_REGION = "ap-southeast-2"
const LOCALSTACK_ACCOUNT_ID  = "000000000000"
const DEVELOPMENT_ACCOUNT_ID = "843407916570"
const STAGING_ACCOUNT_ID = "455634345446"
const PRODUCTION_ACCOUNT_ID = "472057503814"

// new Icav2CredentialsStack(
//     app,
//     `${CDK_APP_NAME}-test-workflow-deployment-role-localstack`,
//     {
//         icav2_base_url: ICAV2_BASE_URL,
//         key_name: "umccr-test-workflow-deployment-localstack",
//         key_ssm_path: "/icav2/workflow-deployment-role-localstack",
//         slack_host_ssm_name: SLACK_HOST_SSM_NAME,
//         slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
//         github_repos: [
//             "repo:umccr/cwl-ica"
//         ],
//         github_role_name: "workflow-deployment-localstack",
//         env: {
//             account: LOCALSTACK_ACCOUNT_ID,
//             region: LOCAL_REGION
//         }
//     }
// );


/* Everything project in ICAv2 development */
new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-umccr-prod-dev`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: 'umccr-prod-service-dev',
        key_ssm_path: "/icav2/umccr-prod/service-user-dev-jwt-token-secret-arn",
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [
            "repo:umccr/cwl-ica:*"
        ],
        github_role_name: "gh-service-user-dev",
        env: {
            account: DEVELOPMENT_ACCOUNT_ID,
            region: DEFAULT_REGION
        },
    }
);


/* Pipelines project in production */
/* Used by cwl-ica GH Actions for deploying pipelines into pipelines project */
/* And then deploying bundles into appropriate projects */
/* Serves bundles to all projects (including staging) */
/* JWT Key cannot download data in dev / staging / production projects */
new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-umccr-prod-service-pipelines-prod`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: 'umccr-prod-service-pipelines',
        key_ssm_path: "/icav2/umccr-prod/service-pipelines-jwt-token-secret-arn",
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [
            "repo:umccr/cwl-ica:*"
        ],
        github_role_name: 'gh-service-icav2-pipeline-user-prod',
        env: {
            account: PRODUCTION_ACCOUNT_ID,
            region: DEFAULT_REGION
        },
    }
);


/* Staging Service */
/* JWT KEY can execute analyses and download data in staging project */
new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-umccr-prod-service-staging`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: 'umccr-prod-service-staging',
        key_ssm_path: "/icav2/umccr-prod/service-staging-jwt-token-secret-arn",
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [],
        github_role_name: null,
        env: {
            account: STAGING_ACCOUNT_ID,
            region: DEFAULT_REGION
        },
    }
);

/* Production Service */
/* JWT KEY can execute analyses and download data in production project */
new Icav2CredentialsStack(
    app,
    `${CDK_APP_NAME}-umccr-prod-service-prod`,
    {
        icav2_base_url: ICAV2_BASE_URL,
        key_name: 'umccr-prod-service-production',
        key_ssm_path: "/icav2/umccr-prod/service-production-jwt-token-secret-arn",
        slack_host_ssm_name: SLACK_HOST_SSM_NAME,
        slack_webhook_ssm_name: SLACK_WEBHOOK_SSM_NAME,
        github_repos: [],
        github_role_name: null,
        env: {
            account: PRODUCTION_ACCOUNT_ID,
            region: DEFAULT_REGION
        },
    }
);
