# Showcase CDK app

Implements a simple [callback-based step function](https://aws.amazon.com/about-aws/whats-new/2019/05/aws-step-functions-support-callback-patterns/) in [CDK Python](https://aws.amazon.com/cdk/).

Please refer to the [official AWS documentation to understand this callback pattern](https://docs.aws.amazon.com/step-functions/latest/dg/connect-to-resource.html#connect-wait-token).

# Quickstart

After deploying the showcase stack via `cdk deploy`:

```
$ cdk deploy
showcase-iap-tes-dev: deploying...
showcase-iap-tes-dev: creating CloudFormation changeset...
 0/6 | 3:28:28 PM | UPDATE_IN_PROGRESS   | AWS::Lambda::Function            | DragenTesLambda (DragenTesLambdaDB8881C8) 
 0/6 | 3:28:29 PM | UPDATE_IN_PROGRESS   | AWS::Lambda::Function            | SampleSheetMapperTesLambda (SampleSheetMapperTesLambdaC0CB211F) 
 0/6 | 3:28:29 PM | UPDATE_IN_PROGRESS   | AWS::Lambda::Function            | FastqMapperTesLambda (FastqMapperTesLambda4ABC9B1E) 
 1/6 | 3:28:29 PM | UPDATE_COMPLETE      | AWS::Lambda::Function            | DragenTesLambda (DragenTesLambdaDB8881C8) 
 2/6 | 3:28:29 PM | UPDATE_COMPLETE      | AWS::Lambda::Function            | SampleSheetMapperTesLambda (SampleSheetMapperTesLambdaC0CB211F) 
 2/6 | 3:28:29 PM | UPDATE_IN_PROGRESS   | AWS::Lambda::Function            | MultiQcTesLambda (MultiQcTesLambda5190EF83) 
 3/6 | 3:28:29 PM | UPDATE_COMPLETE      | AWS::Lambda::Function            | FastqMapperTesLambda (FastqMapperTesLambda4ABC9B1E) 
 4/6 | 3:28:30 PM | UPDATE_COMPLETE      | AWS::Lambda::Function            | MultiQcTesLambda (MultiQcTesLambda5190EF83) 

 ✅  showcase-iap-tes-dev

Stack ARN:
arn:aws:cloudformation:ap-southeast-2:<ACCT>:stack/showcase-iap-tes-dev/d9c10820-4c81-11ea-abb0-06747b07fdba
```

All is needed is just calling the first step of the step function state machine with a runfolder as input:

```shell
$ aws stepfunctions start-execution --state-machine-arn --input '{"runfolder": "200123_A00330_0100_AHMCTVWSXX"}'
```