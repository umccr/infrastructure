# umccr_pipeline_bastion stack

Stack to deploy central resources for the `umccr_pipeline` stack(s) in `dev` and `prod`.

## Dependencies

NOTE: circular dependencies exist in this stack needs to assume roles created by the `dev`/`prod` `umccr_pipeline` stacks.

- local lambda module
- AWS credentials for `bastion` account (read from the environment)
- Corresponding infrastructure setup in `dev`/`prod` accounts (see stack `umccr_pipeline`)