#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { DataBricksSecretsRotationStack } from '../lib/databricks-stack';

const app = new cdk.App();

const PROD_ACCOUNT_ID = '472057503814'
const PROD_ACCOUNT_REGION = 'ap-southeast-2'

// Run in production (we only have the databricks production)
new DataBricksSecretsRotationStack(app, 'DataBricksSecretsRotationStack', {
  /* Uncomment the next line if you know exactly what Account and Region you
   * want to deploy the stack to. */
  env: {
      account: PROD_ACCOUNT_ID,
      region: PROD_ACCOUNT_REGION
  }

  /* For more information, see https://docs.aws.amazon.com/cdk/latest/guide/environments.html */
});