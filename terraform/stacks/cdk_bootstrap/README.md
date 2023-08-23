CDK can be bootstrapped using the CDK CLI tool. However, subsequent upgrading of the CDK
bootstrap template is prone to error - unless the exact same command line
parameters are specified (including the same trusted accounts etc).

It is much safer if the CDK templates are bootstrapped across all our accounts in a controlled manner
using terraform.

The included `bootstrap-template.yaml` is sourced directly from the CDK project.

Newer versions (it does not change that often) can be obtained from

`https://raw.githubusercontent.com/aws/aws-cdk/main/packages/aws-cdk/lib/api/bootstrap/bootstrap-template.yaml`

and should be saved over the top of the `bootstrap-template.yaml` in this folder.

Check the value `CdkBootstrapVersion` to see which version exists in github and
how it compares to the currently deployed one.
