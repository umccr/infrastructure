import {Duration, Stack, StackProps} from 'aws-cdk-lib';
import { ToolkitCleaner } from 'cloudstructs/lib/toolkit-cleaner';
import { Construct } from 'constructs';

export class CleanerStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    new ToolkitCleaner(this, 'ToolkitCleaner', {
      // Do not delete assets created in the last 30 days even if unused
      retainAssetsNewerThan: Duration.days(30),
    });
  }
}
