#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { CleanerStack } from "./lib/cleaner-stack";
import {Duration} from "aws-cdk-lib";

const description = "Cleaner is a service that deletes unused CDK repos and S3 assets each night";

const app = new cdk.App();

// dev
new CleanerStack(app, "CleanerDevStack", {
  description: description,
  env: {
    account: "843407916570",
    region: "ap-southeast-2"
  },
  // do not delete assets created in the last 7 days even if unused
  retainAssetsNewerThan: Duration.days(7),
});

// build (bastion)
new CleanerStack(app, "CleanerBuildStack", {
  description: description,
  env: {
    account: "383856791668",
    region: "ap-southeast-2"
  },
  // do not delete assets created in the last 30 days even if unused
  retainAssetsNewerThan: Duration.days(30),
});
