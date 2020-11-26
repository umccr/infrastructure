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
  ACM
   |      (authz)             |           [private subnets]
Route53 > APIGWv2 > VpcLink > | ALB > (autoscaling) ECS Fargate Cluster
                              |
```

Architecture very similar to this article:
- [Access Private applications on AWS Fargate using Amazon API Gateway PrivateLink](https://aws.amazon.com/blogs/compute/access-private-applications-on-aws-fargate-using-amazon-api-gateway-privatelink/).

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
