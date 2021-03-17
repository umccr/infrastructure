# gen3_compose

Gen3 [compose-service](https://gen3.org/resources/operator/) setup for POC testing.

## TL;DR

- Stack Arch: 
```
  ACM
   |
Route53 > ALB > (hibernating) EC2 Instance
```

- Required **terraform 0.12**
```
terraform --version
Terraform v0.12.26
```

```
aws sso login --profile dev && export AWS_PROFILE=dev
terraform workspace select dev
terraform plan
terraform apply 
```

## Usage

Please see [USERDOC](userdoc)
