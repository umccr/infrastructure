# UMCCRISE

## S3 Trigger
UMCCRISE can be triggered with a file upload to an s3 bucket. To trigger, place a file called `upload_complete` in the data directory of `umccr-primary-data-prod` or `umccr-primary-data-dev`. e.g. `s3://umccr-primary-data-dev/my-cool-data/upload_complete`.