#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { ElsaTestDataStack } from "../lib/elsa_test_data-stack";

const app = new cdk.App();
new ElsaTestDataStack(app, "ElsaTestDataStack", {
  tags: {
    creator: "William",
    stack: "ElsaTestData",
    repository: "infrastructure/cdk/apps/agha/elsa_test_data",
    useCase: "Testing elsa with mock data",
  },
});
