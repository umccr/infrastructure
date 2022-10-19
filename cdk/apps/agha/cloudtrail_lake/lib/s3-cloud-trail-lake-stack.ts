import {
  Stack,
  StackProps,
  aws_cloudtrail as cloudtrail,
  CfnOutput,
} from "aws-cdk-lib";
import { Construct } from "constructs";

interface S3CloudTrailLakeStackProps extends StackProps {
  bucketArn: string;
}

export class S3CloudTrailLakeStack extends Stack {
  constructor(scope: Construct, id: string, props: S3CloudTrailLakeStackProps) {
    super(scope, id, props);
    const cfnEventDataStore = new cloudtrail.CfnEventDataStore(
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
                startsWith: [props.bucketArn],
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
        name: "S3GetEventLogs",
        organizationEnabled: false,
        retentionPeriod: 365, // 1 year (Defined in number of days)
        terminationProtectionEnabled: false,
      }
    );

    // Output value
    new CfnOutput(this, "s3CloudTrailLakeArn", {
      value: cfnEventDataStore.attrEventDataStoreArn,
      description: "The ARN for CloudTrail Lake",
      exportName: "s3CloudTrailLakeArn",
    });
  }
}
