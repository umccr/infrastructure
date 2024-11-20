# ICA ENS

> DEPRECATION NOTICE:
> 
> This stack has been deprecated from all environments. It has been using as temporary measure; in order to trigger weekly BSSH Runs in parallel between ICAv1 & ICAv2 systems as part of early development and migration purpose.
> 
> We are now using more permanent solution with ICAv2 ENS subscription for `bssh.runs` event at OrcaBus.
>   - https://trello.com/c/eRYktdZp
>   - https://github.com/umccr/orcabus/issues/696
> 
> The following instruction no longer applicable anymore.

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
