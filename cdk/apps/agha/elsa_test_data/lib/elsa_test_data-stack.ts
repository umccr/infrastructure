import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { Bucket } from "aws-cdk-lib/aws-s3";
import { CfnEventDataStore } from "aws-cdk-lib/aws-cloudtrail";

export class ElsaTestDataStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Bucket with mock data
    const elsaTestDataBucket = new Bucket(this, "ElsaTestDataBucket", {
      bucketName: "elsa-test-data",
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // CloudTrail logs
    const cfnEventDataStore = new CfnEventDataStore(
      this,
      "CloudTrailEventDataStore",
      {
        advancedEventSelectors: [
          {
            fieldSelectors: [
              {
                field: "eventCategory",
                equalTo: ["Data"],
              },
              {
                field: "resources.type",
                equalTo: ["AWS::S3::Object"],
              },
              {
                field: "resources.ARN",
                startsWith: [elsaTestDataBucket.bucketArn],
              },
              {
                field: "eventName",
                equalTo: ["GetObject"],
              },
            ],

            name: "read-access-s3",
          },
        ],
        multiRegionEnabled: false,
        name: "ElsaTestData-S3EventLogs",
        organizationEnabled: false,
        retentionPeriod: 365, // 1 year (Defined in number of days)
        terminationProtectionEnabled: false,
      }
    );

    // Output value
    new cdk.CfnOutput(this, "S3CloudTrailLakeArn", {
      value: cfnEventDataStore.attrEventDataStoreArn,
      description: "The ARN for CloudTrail Lake",
      exportName: "elsaTestDataCloudTrailLakeARN",
    });
  }
}
