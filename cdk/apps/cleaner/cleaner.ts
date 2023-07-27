#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { CleanerStack } from "./lib/cleaner-stack";

const description = "Cleaner is a service that deletes unused CDK repos and S3 assets each night";

const app = new cdk.App();
new CleanerStack(app, "CleanerStack", {
  description: description,
  env: {
    account: "843407916570",
    region: "ap-southeast-2"
  },
});
