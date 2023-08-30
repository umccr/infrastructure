# Data Processing App

This substack terraform contains resources related to data portal _mini_ app typically data processing.

## TL;DR

```
terraform workspace select dev
terraform plan
terraform apply
```

## Notes

- These processing apps are _NOT_ necessary forming as part of "Portal Workflow Automation". For that aspect, see [pipeline](../pipeline).
- These apps are typically standalone and independent by nature. _(think of microservice)_
- They can be easily shutdown or refactored out from Portal data processing unit, if need be.
