# gen3_compose

Gen3 [compose-service](https://gen3.org/resources/operator/) setup for POC testing.

## TL;DR

- Stack Arch: 
```
  ACM
   |
Route53 > ALB > (hibernating) EC2 Instance
```

- Required **terraform 0.14**
```
terraform --version
Terraform v0.14.9
```

```
aws sso login --profile dev && export AWS_PROFILE=dev
terraform workspace select dev
terraform plan
terraform apply 
```
