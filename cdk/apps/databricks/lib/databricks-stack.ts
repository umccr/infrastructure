import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam'
import * as lambda from 'aws-cdk-lib/aws-lambda'
import {Construct} from 'constructs';
import * as events from 'aws-cdk-lib/aws-events'
import * as events_targets from 'aws-cdk-lib/aws-events-targets'
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager'
import * as ssm from 'aws-cdk-lib/aws-ssm'
import {ISecret} from "aws-cdk-lib/aws-secretsmanager";
import {
    ATHENA_LAMBDA_FUNCTION_NAME,
    ATHENA_OUTPUT_BUCKET_PATH, ATHENA_USER_NAME,
    ATHENA_OUTPUT_BUCKET, DATABRICKS_HOST_URL_PROD,
    ICA_SECRETS_READ_ONLY_SECRET_ID,
    SERVICE_USER_ACCESS_TOKEN_SECRETS_MANAGER_PATH,
    ORCABUS_JWT_SECRETS_MANAGER_ID,
} from "../constants";
import {IParameter} from "aws-cdk-lib/aws-ssm/lib/parameter";

export class DataBricksSecretsRotationStack extends cdk.Stack {

    private add_deny_for_everyone_except_lambda_functions(secret_obj: ISecret, lambda_functions: lambda.Function[]){
        /*
        Deny access to secret for all except for the lambda functions
        */
        secret_obj.addToResourcePolicy(
            new iam.PolicyStatement(
                {
                    effect: iam.Effect.DENY,
                    actions: ["secretsmanager:GetSecretValue"],
                    resources: ["*"],
                    principals: [
                        new iam.AccountRootPrincipal()
                    ],
                    conditions: {
                        "ForAllValues:StringNotEquals": {
                            "aws:PrincipalArn": lambda_functions.map(
                                (lambda_function_obj) => lambda_function_obj.role?.roleArn
                            )
                        }
                    }
                }
            )
        )
    }

    private create_user_with_role(user_id: string, user_name: string, role_id: string): [iam.User, iam.Role] {
        /*
        Create a user and a role,
        Allow the user to assume the role
        */

        // Create user
        let user = new iam.User(
            this,
            user_id,
            {
                userName: user_name
            }
        )

        // Create role
        let role = new iam.Role(
            this,
            role_id,
            {
                assumedBy: new iam.ArnPrincipal(user.userArn)
            }
        )

        // Attach user to role
        user.attachInlinePolicy(
            new iam.Policy(
                this,
                "ica_assume_role_to_user",
                {
                    statements: [
                        new iam.PolicyStatement(
                            {
                                actions: [
                                    "sts:AssumeRole"
                                ],
                                resources: [
                                    role.roleArn
                                ]
                            }
                        )
                    ]
                }
            )
        )

        return [user, role]
    }

    private attach_athena_policies_to_iam_role(role_obj: iam.Role, athena_output_bucket: string, athena_output_bucket_path: string, athena_lambda_function_name: string) {
        /*
        From https://docs.aws.amazon.com/athena/latest/ug/udf-iam-access.html
        Create an athena access policy,
        Attach it to the role object
        */
        let athena_full_access_policy = iam.ManagedPolicy.fromAwsManagedPolicyName(
            "AmazonAthenaFullAccess"
        )

        let athena_invoke_lambda_function = new iam.PolicyStatement(
            {
                actions: [
                    "lambda:InvokeFunction"
                ],
                resources: [
                    `arn:aws:lambda:*:${this.account}:function:${athena_lambda_function_name}`
                ]
            }
        )

        //
        // Athena Full Access has permissions for the wrong bucket
        /*         {
            "Sid": "BaseQueryResultsPermissions",
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload",
                "s3:CreateBucket",
                "s3:PutObject",
                "s3:PutBucketPublicAccessBlock"
            ],
            "Resource": [
                "arn:aws:s3:::aws-athena-query-results-*"
            ]
        }
        */
        let allow_output_access = new iam.PolicyStatement(
            {
                actions: [
                    "s3:GetBucketLocation",
                    "s3:GetObject",
                    "s3:ListBucket",
                    "s3:ListBucketMultipartUploads",
                    "s3:ListMultipartUploadParts",
                    "s3:AbortMultipartUpload",
                    "s3:CreateBucket",
                    "s3:PutObject",
                    "s3:PutBucketPublicAccessBlock"
                ],
                resources: [
                    `arn:aws:s3:::${athena_output_bucket}`,
                    `arn:aws:s3:::${athena_output_bucket}/*`,
                    `arn:aws:s3:::${athena_output_bucket}/${athena_output_bucket_path}/*`
                ]
            }
        )

        // Tie access policy to role
        role_obj.addManagedPolicy(athena_full_access_policy)

        // athena_full_access_policy.attachToRole(role_obj)
        role_obj.addToPolicy(athena_invoke_lambda_function)

        // Add s3 output access
        role_obj.addToPolicy(allow_output_access)

        //
        // let athena_access_policy = new iam.Policy(
        //     this,
        //     "athena_access_policy",
        //     {
        //         document: new iam.PolicyDocument(
        //             {
        //                 statements: [
        //                     // From https://docs.aws.amazon.com/athena/latest/ug/udf-iam-access.html
        //                     new iam.PolicyStatement({
        //                         actions: [
        //                             "athena:StartQueryExecution",
        //                             "lambda:InvokeFunction",
        //                             "athena:GetQueryResults",
        //                             "s3:ListMultipartUploadParts",
        //                             "athena:GetWorkGroup",
        //                             "s3:PutObject",
        //                             "s3:GetObject",
        //                             "s3:AbortMultipartUpload",
        //                             "athena:StopQueryExecution",
        //                             "athena:GetQueryExecution",
        //                             "s3:GetBucketLocation"
        //                         ],
        //                         resources: [
        //                             `arn:aws:athena:*:${this.account}:workgroup/${athena_workgroup_name}`,
        //                             `arn:aws:s3:::${athena_output_bucket_path}/*`,
        //                             `arn:aws:lambda:*:${this.account}:function:${athena_lambda_function_name}`
        //                         ]
        //                     }),
        //                     // From https://docs.aws.amazon.com/athena/latest/ug/udf-iam-access.html
        //                     new iam.PolicyStatement(
        //                         {
        //                             actions: [
        //                                 "athena:ListWorkGroups"
        //                             ],
        //                             resources: [
        //                                 "*"
        //                             ]
        //                         }
        //                     ),
        //                     // From https://stackoverflow.com/questions/66348736/startqueryexecution-operation-unable-to-verify-create-output-bucket
        //                     new iam.PolicyStatement(
        //                         {
        //                             actions: [
        //                                 "s3:GetBucketLocation"
        //                             ],
        //                             resources: [
        //                                 "arn:aws:s3:::*"
        //                             ]
        //                         }
        //                     ),
        //                     // From https://docs.aws.amazon.com/athena/latest/ug/datacatalogs-iam-policy.html
        //                     new iam.PolicyStatement(
        //                         {
        //                             actions: [
        //                                 "athena:GetDataCatalog"
        //                             ],
        //                             resources: [
        //                                 `arn:aws:athena:${this.region}:${this.account}:datacatalog/${ATHENA_DATA_CATALOG}`
        //                             ]
        //                         }
        //                     )
        //                 ]
        //             }
        //         )
        //     }
        // )
    }

    private create_docker_image_function_with_standard_role(role_id: string, role_name: string, lambda_id: string, lambda_name: string, lambda_description: string, lambda_directory_path: string): [iam.Role, lambda.DockerImageFunction] {
        /*
        Create a docker image function with a standard role
        */
        // Step 1 - Create the lambda role
        let lambda_role = new iam.Role(
            this,
            role_id,
            {
                assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
                roleName: role_name,
                managedPolicies: [
                    iam.ManagedPolicy.fromAwsManagedPolicyName(
                        'service-role/AWSLambdaBasicExecutionRole'
                    ),
                    iam.ManagedPolicy.fromAwsManagedPolicyName(
                        'service-role/AWSLambdaVPCAccessExecutionRole'
                    )
                ]
            }
        )

        // Create DockerImage-based lambda Function
        let lambda_image_function = new lambda.DockerImageFunction(
            this,
            lambda_id,
            {
                functionName: lambda_name,
                description: lambda_description,
                code: lambda.DockerImageCode.fromImageAsset(
                    lambda_directory_path,
                ),
                role: lambda_role,
                timeout: cdk.Duration.seconds(60),
            }
        )

        // Return lambda role and image
        return [lambda_role, lambda_image_function]
    }

    private add_athena_permissions_to_lambda_function(databricks_service_user_secret: ISecret, athena_user: iam.User, athena_access_rotator_lambda_function: lambda.Function) {
        /*
         Add permissions to function
         Allow get secret value for SERVICE_USER_ACCESS_TOKEN_SECRETS_MANAGER_PATH
        */

        // Add secrets permissions to lambda function
        athena_access_rotator_lambda_function.addToRolePolicy(
            new iam.PolicyStatement(
                {
                    actions: [
                        "secretsManager:GetSecretValue"
                    ],
                    resources: [
                        databricks_service_user_secret.secretArn
                    ]
                }
            )
        )

        // Add statement to list all iam users
        athena_access_rotator_lambda_function.addToRolePolicy(
            new iam.PolicyStatement(
                {
                    actions: [
                        "iam:ListUsers",
                    ],
                    resources: [
                        `arn:aws:iam::${this.account}:user/*`
                    ]
                }
            )
        )

        // Allow role access to add / list and delete this iam user's specific keys
        athena_access_rotator_lambda_function.addToRolePolicy(
            new iam.PolicyStatement(
                {
                    actions: [
                        "iam:ListAccessKeys",
                        "iam:CreateAccessKey",
                        "iam:DeleteAccessKey"
                    ],
                    resources: [
                        athena_user.userArn
                    ]
                }
            )
        )
    }

    private add_secrets_access_permissions_to_sync_function(secrets_to_access_read_only: ISecret[], sync_lambda_function: lambda.Function) {
        /*
        Grant access to lambda function
        */
        secrets_to_access_read_only.forEach((secret_obj) => secret_obj.grantRead(sync_lambda_function))
    }

    private add_ssm_parameter_get_permissions_to_lambda_function_role(ssm_parameter: IParameter, lambda_function: lambda.Function){
        /*
        Allows the lambda function access to get the ssm parameter
        */
        ssm_parameter.grantRead(lambda_function)
    }

    private add_schedule(rule_id: string, rule_frequency: string, input_json: Object, target_lambda_function: lambda.Function) {
        /*
         Add trigger to lambda rotation function
         Create a rule to trigger this lambda function
        */

        // Create rotation schedule rule
        let rotation_schedule_rule = new events.Rule(
            this,
            rule_id,
            {
                schedule: events.Schedule.expression(`rate(${rule_frequency})`),
            }
        )

        // Add event target
        // Add lambda invocation as target to rule
        rotation_schedule_rule.addTarget(
            new events_targets.LambdaFunction(
                target_lambda_function,
                {
                    event: events.RuleTargetInput.fromObject(
                        input_json
                    )
                }
            )
        )
    }

    constructor(scope: Construct, id: string, props?: cdk.StackProps) {
        super(scope, id, props);

        // Get databricks service user access token as a secret object
        let databricks_service_user_access_token_secret = new secretsmanager.Secret(
            this,
            "databricks_service_user_access_token_secret",
            {
                secretName: SERVICE_USER_ACCESS_TOKEN_SECRETS_MANAGER_PATH,
                description: "Databricks service user token, used for updating databricks secrets"
            }
        )

        // Create the databricks host as a ssm parameter
        let databricks_host_ssm_parameter = new ssm.StringParameter(
            this,
            "databricks_host_ssm_parameter",
            {
                stringValue: DATABRICKS_HOST_URL_PROD
            }
        )

        // Part 1 - Set up User and Role
        let [athena_user, athena_role] = this.create_user_with_role(
            "athena_user",
            ATHENA_USER_NAME,
            "athena_role"
        )

        // Add Policies to Role
        this.attach_athena_policies_to_iam_role(
            athena_role,
            ATHENA_OUTPUT_BUCKET,
            ATHENA_OUTPUT_BUCKET_PATH,
            ATHENA_LAMBDA_FUNCTION_NAME
        )


        // End of User Access Setup

        // Athena Lambda Rotator Function setup with scheduler
        let [athena_access_rotator_role, athena_access_rotator_lambda_function] = this.create_docker_image_function_with_standard_role(
            "athena_rotator_role",
            "databricks_athena_user_keys_rotator_role",
            "athena_rotator_lambda",
            "databricks_athena_user_keys_rotator_function",
            "Create new access keys for athena user and copy them to DataBricks",
            "./lambdas/rotate_athena_user_access_keys"
        )

        // Add athena permissions to lambda function
        this.add_athena_permissions_to_lambda_function(
            databricks_service_user_access_token_secret,
            athena_user,
            athena_access_rotator_lambda_function
        )

        // Add permission to get access to the host ssm parameter
        this.add_ssm_parameter_get_permissions_to_lambda_function_role(
            databricks_host_ssm_parameter,
            athena_access_rotator_lambda_function
        )

        // Add lambda rotation schedule
        this.add_schedule(
            "athena_access_rotation_schedule",
            "7 days",
            {
                ATHENA_USER_NAME: ATHENA_USER_NAME,
                DATABRICKS_SERVICE_USER_TOKEN_SECRETS_MANAGER_ARN: databricks_service_user_access_token_secret.secretArn,
                DATABRICKS_HOST_SSM_PARAMETER_NAME: databricks_host_ssm_parameter.parameterName,
                DATABRICKS_ATHENA_ROLE_ARN: athena_role.roleArn
            },
            athena_access_rotator_lambda_function
        )
        // End of Athena Lambda Rotator Function setup with scheduler

        // ICA Access Token Lambda function with daily scheduler
        // Get ICA Access token as a secret object

        let ica_access_token_secret = secretsmanager.Secret.fromSecretNameV2(
            this,
            "ica_secrets_read_only_path",
            ICA_SECRETS_READ_ONLY_SECRET_ID
        )

        let [ica_access_token_sync_lambda_role, ica_access_token_sync_lambda_function] = this.create_docker_image_function_with_standard_role(
            "ica_access_token_sync_role",
            "databricks_ica_access_token_sync_role",
            "ica_access_token_sync_lambda_function",
            "databricks_ica_access_token_sync_lambda_function",
            "Get current ICA JWT and sync to DataBricks",
            "./lambdas/sync_icav1_jwt"
        )

        // Add permissions to function
        // Allow get secret value for SERVICE_USER_ACCESS_TOKEN_SECRETS_MANAGER_PATH
        this.add_secrets_access_permissions_to_sync_function(
            [databricks_service_user_access_token_secret, ica_access_token_secret],
            ica_access_token_sync_lambda_function
        )

        // Add permission to get access to the host ssm parameter
        this.add_ssm_parameter_get_permissions_to_lambda_function_role(
            databricks_host_ssm_parameter,
            ica_access_token_sync_lambda_function
        )

        // Add lambda rotation schedule
        this.add_schedule(
            "ica_access_rotation_schedule",
            "1 day",
            {
                ICA_ACCESS_TOKEN_SECRETS_MANAGER_ARN: ica_access_token_secret.secretArn,
                DATABRICKS_SERVICE_USER_TOKEN_SECRETS_MANAGER_ARN: databricks_service_user_access_token_secret.secretArn,
                DATABRICKS_HOST_SSM_PARAMETER_NAME: databricks_host_ssm_parameter.parameterName
            },
            ica_access_token_sync_lambda_function
        )
        // End of ICA Access Token Lambda function with daily schedule

        // Repeat for the orcabus token
        let orcabus_token_secret = secretsmanager.Secret.fromSecretNameV2(
            this,
            "orcabus_secret",
            ORCABUS_JWT_SECRETS_MANAGER_ID
        )

        let [orcabus_token_sync_lambda_role, orcabus_token_sync_lambda_function] = this.create_docker_image_function_with_standard_role(
            "orcabus_token_sync_role",
            "databricks_orcabus_token_sync_role",
            "orcabus_token_sync_lambda_function",
            "databricks_orcabus_token_sync_lambda_function",
            "Get current orcabus JWT and sync to DataBricks",
            "./lambdas/sync_orcabus_jwt"
        )

        // Add permissions to function
        // Allow get secret value for SERVICE_USER_ACCESS_TOKEN_SECRETS_MANAGER_PATH
        this.add_secrets_access_permissions_to_sync_function(
            [databricks_service_user_access_token_secret, orcabus_token_secret],
            orcabus_token_sync_lambda_function
        )

        // Add permission to get access to the host ssm parameter
        this.add_ssm_parameter_get_permissions_to_lambda_function_role(
            databricks_host_ssm_parameter,
            orcabus_token_sync_lambda_function
        )

        // Add lambda rotation schedule
        // Orcabus token expires every 24 hours
        this.add_schedule(
            "orcabus_jwt_access_rotation_schedule",
            "12 hours",
            {
                ORCABUS_TOKEN_SECRETS_MANAGER_ARN: orcabus_token_secret.secretArn,
                DATABRICKS_SERVICE_USER_TOKEN_SECRETS_MANAGER_ARN: databricks_service_user_access_token_secret.secretArn,
                DATABRICKS_HOST_SSM_PARAMETER_NAME: databricks_host_ssm_parameter.parameterName
            },
            orcabus_token_sync_lambda_function
        )

        // Final adjustment - remove access to databricks secret for everyone except for the lambda functions
        this.add_deny_for_everyone_except_lambda_functions(
            databricks_service_user_access_token_secret,
            [
                orcabus_token_sync_lambda_function,
                ica_access_token_sync_lambda_function,
                athena_access_rotator_lambda_function
            ]
        )
    }
}
