# ICA ENS

```
terraform workspace list
  default
  dev
* prod
  stg

export AWS_PROFILE=umccr-prod-admin && terraform workspace select prod && terraform plan
terraform apply
```

```
unset ICA_ACCESS_TOKEN

ica logout
ica login

ica workgroups list
ica subscriptions list
ica subscriptions list | grep bssh

ica workgroups enter clinical-genomics-workgroup
ica subscriptions list

ica subscriptions create \
  --name "UMCCRBsshRunsOrcaBusSRMProd" \
  --type "bssh.runs" \
  --actions "statuschanged" \
  --description "UMCCR OrcaBus SequenceRunManager (PROD) subscribe to bssh.runs statuschanged events using clinical-genomics-workgroup" \
  --aws-sqs-queue "https://sqs.ap-southeast-2.amazonaws.com/472057503814/ica-ens-queue"
```
