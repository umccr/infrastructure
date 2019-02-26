# umccr_pipeline stack

Stack to deploy resources for the AWS Step Function based pre-analysis pipeline. This pipeline consists of:
- sample sheet checking and splitting if necessary
- demultiplexing using bcl2fastq
- checksumming 
- data transfer to HPC
- data transfer to S3

## Dependencies

NOTE: circular dependencies exist in that this stack needs to reference resources created by the `umccr_pipeline_bastion` stack, which in turn references this stack.
These resources are defined in variables:
- ssm_role_to_assume_arn
- ssm_run_document_name

- local lambda module
- AWS credentials for `dev` and/or `prod` account (read from the environment)
- Infrastructure setup in `bastion` account dealing with SSM commands for `novastor` (see stack `umccr_pipeline_bastion`)