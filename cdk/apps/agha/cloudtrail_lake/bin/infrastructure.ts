#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { S3CloudTrailLakeStack } from "../lib/s3-cloud-trail-lake-stack";

const props = {
  bucketArn: "arn:aws:s3:::agha-gdr-store-2.0",
};

const stackTags = {
  stack: "S3CloudTrailLakeStack",
  creator: "william",
  repository: "infrastructure",
  useCase: "Tracking AG bucket access.",
};
const app = new cdk.App();
new S3CloudTrailLakeStack(app, "S3CloudTrailLakeStack", {
  tags: stackTags,
  bucketArn: props.bucketArn,
});
