/*
This is a manually generated token from the service user account.
This access token allows the creation of DataBricks secrets.
The lambda function that copies the JWT token from AWS to DataBricks will need this secret
*/

// Added in manually
// Can only be accessed by the lambda rotation functions
export const SERVICE_USER_ACCESS_TOKEN_SECRETS_MANAGER_PATH = "/databricks/access_tokens/service_user"

// ICA Secrets Portal
// https://github.com/umccr/infrastructure/tree/master/cdk/apps/ica_credentials
export const ICA_SECRETS_READ_ONLY_PATH = "IcaSecretsPortal-Catuey"

// Athena functions
// Doesn't actually correlate to data_portal though, not sure where this is sourced from
// https://github.com/umccr/infrastructure/blob/9685c9715b2984e69d57feb74bd679dd7a04d2f3/terraform/stacks/umccr_data_portal/athena.tf#L46
export const ATHENA_LAMBDA_FUNCTION_NAME = "data_portal"

// Athena Output Results Path
// https://github.com/umccr/infrastructure/blob/9685c9715b2984e69d57feb74bd679dd7a04d2f3/terraform/stacks/umccr_data_portal/athena.tf#L53C1-L53C1
export const ATHENA_OUTPUT_BUCKET = "umccr-data-portal-build-prod"
export const ATHENA_OUTPUT_BUCKET_PATH = "athena-query-results"

// Athena WorkGRoup Name
// https://github.com/umccr/infrastructure/blob/9685c9715b2984e69d57feb74bd679dd7a04d2f3/terraform/stacks/umccr_data_portal/athena.tf#L45
export const ATHENA_DATA_CATALOG = "data_portal"

// Databricks Athena User Name
export const ATHENA_USER_NAME = "databricks_athena_user"

// Databricks configuration
export const DATABRICKS_HOST_URL_PROD = "https://dbc-88bcc9af-77de.cloud.databricks.com"
