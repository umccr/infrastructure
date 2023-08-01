import {Duration, Stack, StackProps} from 'aws-cdk-lib';
import {ToolkitCleaner, ToolkitCleanerProps} from 'cloudstructs/lib/toolkit-cleaner';
import { Construct } from 'constructs';

export class CleanerStack extends Stack {
  constructor(scope: Construct, id: string, props: StackProps & ToolkitCleanerProps) {
    super(scope, id, props);

    new ToolkitCleaner(this, 'ToolkitCleaner', props);
  }
}
