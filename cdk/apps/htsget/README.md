# htsget-refserver 

UMCCR Deployment of [`htsget-refserver`](https://github.com/ga4gh/htsget-refserver) implementation

## TL;DR

```
pip install -r requirements.txt

cdk list
cdk diff
cdk synth
cdk deploy
cdk destroy
```

## Architecture
```
        GA4GH Passport                       GA4GH htsget
  ACM        |                                     |
   |   (Lambda Authz)         |           (private subnets)
Route53 > APIGWv2 > VpcLink > | ALB > (autoscaling) ECS Fargate Cluster
                              |
```

Architecture very similar to this article:
- [Access Private applications on AWS Fargate using Amazon API Gateway PrivateLink](https://aws.amazon.com/blogs/compute/access-private-applications-on-aws-fargate-using-amazon-api-gateway-privatelink/).
- [Configuring private integrations with Amazon API Gateway HTTP APIs](https://aws.amazon.com/blogs/compute/configuring-private-integrations-with-amazon-api-gateway-http-apis/)

![1-ALB-Example.png](https://d2908q01vomqb2.cloudfront.net/1b6453892473a467d07372d45eb05abc2031647a/2021/02/04/1-ALB-Example.png)

![graph1.png](https://d2908q01vomqb2.cloudfront.net/1b6453892473a467d07372d45eb05abc2031647a/2019/06/17/graph1.png)

## Prerequisites

Need to prepare the following SSM parameters in given AWS account.

- ACM SSL Certificate ARN at: `/htsget/acm/apse2_arn`
- Domain Name at: `/htsget/domain`
- Route53 Hosted Zone Name at: `/hosted_zone_name`
- Route53 Hosted Zone ID at: `/hosted_zone_id`

## Config

`htsget-refserver` [Config JSON](https://github.com/ga4gh/htsget-refserver#configuration) is stored as AWS SSM parameter.

Parameter store key is at: `/htsget/refserver/config`

Using CLI:
```
aws ssm get-parameter --name '/htsget/refserver/config' --output text --query Parameter.Value
```

Alternatively, use AWS SSM Console UI.

#### Updating Config

1. Update new config in parameter store
    ```
    aws ssm put-parameter --name '/htsget/refserver/config' --type String --tier Advanced --value file://config/dev.json --overwrite
    ```
2. Terminate any existing running `htsget-refserver` main containers


## Lambda Development


[GA4GH Passport Clearinghouse](https://github.com/ga4gh-duri/ga4gh-duri.github.io/blob/master/researcher_ids/ga4gh_passport_v1.md) is implemented as AWS API Gateway v2's [Lambda Authorizer](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-lambda-authorizer.html). 

- **TL;DR** dev workflow:
    ```
    make test
    make deploy
    ```

- This lambda authorizer Python module is inside [lambdas/ppauthz](lambdas/ppauthz).

- For current trusted Passport Brokers, see `TRUSTED_BROKERS` module variable in [ppauthz.py](lambdas/ppauthz/ppauthz.py).
   
    > 🙋‍♂️ You will need to have compliant Passport Visa Token from this list of trusted brokers; in order to call UMCCR *secured* htsget endpoints.

- To run tests:
  
    **TL;DR:**
    ```
    make test
    ```

    ```
    cd lambdas/ppauthz
    python -m unittest
    python -m unittest test_ppauthz.PassportAuthzUnitTest.test_handler
    python -m unittest test_ppauthz.PassportAuthzIntegrationTest.test_handler_it
    ```
    > 🙋‍♂️Read more in the PyDoc string!

- If you update this [lambdas/requirements.txt](lambdas/requirements.txt) file:
  
    **TL;DR:**
    ```
    make refresh_deploy
    ```
  
    If you update Lambda Python dependency, make sure to delete [lambdas/.build](lambdas/.build) staging directory. Before applying `cdk diff && cdk deploy`.
    
    > 🙋‍♂️ Lambda Python dependency is packaged and deployed as Lambda Layer. It contains **platform dependant cryptography** library. Hence, required AWS Lambda Docker image to build and packaging it!
