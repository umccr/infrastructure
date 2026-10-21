# UMCCR Docs Domain

- TLS certificate for the docs.umccr.org documentation site, whose hosting (S3, CloudFront, Route 53 alias) lives in
  [umccr/docs-platform](https://github.com/umccr/docs-platform), in the `UMCCR-DocsHostingStack` stack.
- The certificate is issued in `us-east-1`, as CloudFront requires. Its ARN is published to the SSM parameter
  `/docs/certificate_arn` in `ap-southeast-2`, which the docs hosting stack reads at deploy time. The portal does the
  same with `/orcaui/certificate_arn`.
- Readers sign in through the `docs-app-<workspace>` Cognito app client, defined in [cognito_aai](../cognito_aai)
  (`app_docs.tf`).

| Workspace | Certificate names                       |
| --------- | --------------------------------------- |
| dev       | `docs.dev.umccr.org`                    |
| prod      | `docs.prod.umccr.org`, `docs.umccr.org` |

docs.umccr.org has no stage in stg, so this stack has no `stg` workspace; a plan in any other workspace stops with an
error.

## Deploy

Login to AWS.

```
aws sso login --profile=dev && export AWS_PROFILE=dev
```

This stack uses terraform workspaces, one per account, like `cognito_aai`.

```
terraform workspace select dev
terraform plan
terraform apply
```

In `dev`, apply waits until ACM has validated the certificate through the stage zone.

## Prod: records in the umccr.org zone

The `umccr.org` zone is in the bastion account, and no Terraform manages it, so this stack does not write to it: its
records, the `portal.umccr.org` ones included, are added by hand. After applying `prod`, within 72 hours:

1. Read the records to create, with prod credentials:
   ```
   terraform workspace select prod
   terraform output -json umccr_org_zone_records > /tmp/umccr-org-records.json
   ```
   - the ACM validation CNAME for `docs.umccr.org`;
   - `docs.umccr.org` as a CNAME of `docs.prod.umccr.org`.
2. Add both to the `umccr.org` zone with an admin profile for the bastion account (`umccr-bastion-admin` in
   `scripts/all-accounts-aws-config.ini`). `CREATE` refuses the whole change if either record exists already:
   ```
   aws sso login --profile=umccr-bastion-admin && export AWS_PROFILE=umccr-bastion-admin
   ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name umccr.org --max-items 1 \
     --query "HostedZones[?Name=='umccr.org.'].Id | [0]" --output text)
   jq '{Changes: [.[] | {Action: "CREATE", ResourceRecordSet: {Name: .name, Type: .type, TTL: 300,
     ResourceRecords: [{Value: .value}]}}]}' /tmp/umccr-org-records.json > /tmp/umccr-org-change.json
   aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" \
     --change-batch file:///tmp/umccr-org-change.json
   ```
   Or in the bastion account's Route 53 console: **Hosted zones → umccr.org → Create record**, a CNAME with TTL 300
   for each, typing only the part of the name before `.umccr.org`.
3. Check that both resolve at the zone's name server, for example
   `dig +short CNAME docs.umccr.org @$(dig +short NS umccr.org | head -1)`. Wait for the certificate to show
   **Issued** in ACM (`us-east-1`), then let the docs pipeline, `UMCCR-DocsInfrastructure`, promote the hosting stack
   to prod. CloudFront rejects a certificate that is still pending.

Keep the validation record: ACM checks it again at every renewal. umccr/docs-platform's `docs/deploy.md` has the
same steps with every check.

ACM stops validating after 72 hours. A certificate whose `docs.umccr.org` record was not there in time shows
**Validation timed out** (`VALIDATION_TIMED_OUT`) and is never issued. Request a new one in the `prod` workspace,
then check the records the output lists against the zone, and wait for **Issued** again. ACM gives a name the same
validation record for every certificate in the account, so the one already added normally still applies:

```
terraform apply -replace=aws_acm_certificate.docs
terraform output umccr_org_zone_records
```

The replacement is created before the old certificate is removed (`create_before_destroy`), and
`/docs/certificate_arn` moves to it, so the docs hosting stack picks it up at its next deploy.

## Order across repositories

1. `cognito_aai`: apply `app_docs.tf` to the workspace.
2. `umccr_docs_domain` (this stack): apply to the workspace.
3. The docs hosting stack, `UMCCR-DocsHostingStack` in umccr/docs-platform, deploys to that stage through its
   pipeline. It reads both stacks' SSM parameters at deploy time, so it fails early if either is missing.
