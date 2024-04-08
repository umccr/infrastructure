import * as cdk from 'aws-cdk-lib';
import {Construct} from 'constructs';
import {Duration, Stack, StackProps} from "aws-cdk-lib";

import * as secretsManager from 'aws-cdk-lib/aws-secretsmanager';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import * as events from 'aws-cdk-lib/aws-events';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as eventsTargets from 'aws-cdk-lib/aws-events-targets';
import {PythonFunction, PythonLayerVersion} from '@aws-cdk/aws-lambda-python-alpha';

import {join} from "path";

// import * as sqs from 'aws-cdk-lib/aws-sqs';

interface PieriandxCredentialsStackProps extends StackProps {
    pieriandx_base_url: string,
    pieriandx_institution: string,
    api_key_name: string,
    jwt_key_name: string,
    collect_function_name: string,
    key_ssm_root: string,
    slack_host_ssm_name: string,
    slack_webhook_ssm_name: string,
    env: {
        account: string
        region: string
    },
}

export class PieriandxCredentialsStack extends cdk.Stack {

    private lambda_layer_version_obj: PythonLayerVersion
    constructor(scope: Construct, id: string, props: PieriandxCredentialsStackProps) {
        super(scope, id, props);

        // Create the master secret (we will update this with the actual api key later on)
        const master_secret: secretsManager.Secret = this.create_master_secret(props.api_key_name)

        // Generate layers
        this.lambda_layer_version_obj = this.get_lambda_layer_obj()

        // Create the jwt token and get_token function
        const [jwt_secret, jwt_func]: [secretsManager.Secret, PythonFunction] = this.create_jwt_secret(
            master_secret,
            props.pieriandx_base_url,
            props.jwt_key_name,
            props.collect_function_name
        )

        // Set the policy for the master secret
        this.deny_all_except_rotator(
            master_secret,
            [
                jwt_func
            ]
        )

        // Add log rotation events to slack
        this.create_event_handling(
            [
                jwt_secret
            ],
            props.slack_host_ssm_name,
            props.slack_webhook_ssm_name
        )


        // Add SSM Parameter to link to JWT path
        this.create_ssm_parameter_for_jwt_secret_arn(
            jwt_secret.secretName,
            `${props.key_ssm_root}/secretName`
        )
        this.create_ssm_parameter_for_jwt_secret_arn(
            jwt_secret.secretArn,
            `${props.key_ssm_root}/secretArn`
        )

    }

    private get_lambda_layer_obj(): PythonLayerVersion {
        return new PythonLayerVersion(
          this,
          'cttso_v2_tool_layer',
          {
            entry: join(__dirname, "../layers/"),
            compatibleRuntimes: [lambda.Runtime.PYTHON_3_11],
            compatibleArchitectures: [lambda.Architecture.X86_64],
            license: 'GPL3',
            description: 'A layer to enable the pieriandx manager tools layer',
            bundling: {
              commandHooks: {
                beforeBundling(inputDir: string, outputDir: string): string[] {
                  return [];
                },
                afterBundling(inputDir: string, outputDir: string): string[] {
                  return [
                    `python -m pip install ${inputDir} -t ${outputDir}`,
                  ];
                },
              },
            },
          });
    }

    private create_master_secret(key_name: string): secretsManager.Secret {
        /*
        Create the API key for this secret
        */

        let master_api_key_secret: secretsManager.Secret;
        master_api_key_secret = new secretsManager.Secret(
            this,
            `PierianDxApiKey${key_name}`,
            {
                secretName: key_name,
                description: "Master Pieriandx Username / Password - not for direct use - use corresponding JWT secrets instead"
            }
        );

        return master_api_key_secret
    }

    private deny_all_except_rotator(
        secret_obj: secretsManager.Secret,
        rotator_functions: PythonFunction[]  // In the event that we need to create multiple JWTs from the same secret
    ) {
        /*
        Sets up the master secret resource policy so that only the rotator for the JWT secrets can access the
        GetSecretValue for the api key
        */
        let functions_arns_to_allow: string[] = []

        // Check all functions are defined
        for (let rotator_function of rotator_functions) {
            // Check role is not undefined first
            if (rotator_function.role === undefined) {
                throw new Error(`Could not get role of function ${rotator_function.functionArn}`)
            }
            functions_arns_to_allow.push(
                rotator_function.role.roleArn
            )
        }

        // Deny all to master secret except for rol
        secret_obj.addToResourcePolicy(
            new iam.PolicyStatement({
                    effect: iam.Effect.DENY,
                    actions: ["secretsmanager:GetSecretValue"],
                    resources: ["*"],  // No resources allowed by default
                    principals: [new iam.AccountRootPrincipal()],
                    conditions: {
                        "ForAllValues:StringNotEquals": {
                            "aws:PrincipalArn": functions_arns_to_allow
                        }
                    }
                }
            )
        )
    }

    private create_jwt_secret(
        master_secret: secretsManager.Secret,
        pieriandx_base_url: string,
        key_name: string,
        collect_function_name: string
    ): [secretsManager.Secret, PythonFunction] {

        const jwt_producer_lambda_path = join(__dirname, "../lambdas/pieriandx_jwt_producer")
        const jwt_collector_lambda_path = join(__dirname, "../lambdas/pieriandx_jwt_collector")

        /*
        Create the two functions, the producer and the collector
        */
        const pieriandx_jwt_lambda_producer = new PythonFunction(
            this,
            `PierianDxJwtProducer${key_name}`,
            {
                runtime: lambda.Runtime.PYTHON_3_11,
                entry: jwt_producer_lambda_path,
                index: "lambda_entrypoint.py",
                handler: "main",
                memorySize: 1024,
                timeout: Duration.seconds(60),  // Magic
                environment: {
                    "PIERIANDX_BASE_URL": pieriandx_base_url,
                    "PIERIANDX_API_KEYNAME": master_secret.secretName
                },
                layers: [this.lambda_layer_version_obj]
            }
        )

        // Give the newly created lambda object instant access to the api key
        // Note we update the permissions in a later step
        master_secret.grantRead(pieriandx_jwt_lambda_producer)

        // Generate the secret now
        let pieriandx_jwt_secret: secretsManager.Secret = new secretsManager.Secret(
            this,
            `PierianDx${key_name}`,
            {
                secretName: key_name,
                description: "JWT providing access to PierianDx projects"
            }
        )

        const pieriandx_jwt_lambda_collector = new PythonFunction(
            this,
            `PierianDxJwtCollector${key_name}`,
            {
                functionName: collect_function_name,
                runtime: lambda.Runtime.PYTHON_3_11,
                entry: jwt_collector_lambda_path,
                index: "lambda_entrypoint.py",
                handler: "main",
                memorySize: 1024,
                timeout: Duration.seconds(60),  // Magic
                environment: {
                    "PIERIANDX_JWT_KEYNAME": pieriandx_jwt_secret.secretName
                },
                layers: [this.lambda_layer_version_obj]
            }
        )

        // Add the lambda to the rotation policy
        pieriandx_jwt_secret.addRotationSchedule(
            `PierianDxJWT${key_name}RotationSchedule`,
            {
                rotationLambda: pieriandx_jwt_lambda_producer
                // No rotation schedule - we will trigger this manually
            }
        )

        // Allow the collector to read the secret
        pieriandx_jwt_secret.grantRead(pieriandx_jwt_lambda_collector)

        // Allow the collector lambda to trigger the secret rotation for pieriandx_jwt
        // https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/secretsmanager/client/rotate_secret.html
        pieriandx_jwt_lambda_collector.addToRolePolicy(
            new iam.PolicyStatement({
                actions: [
                    "secretsmanager:RotateSecret"
                ],
                resources: [
                    pieriandx_jwt_secret.secretArn
                ]
            })
        )
        pieriandx_jwt_lambda_producer.grantInvoke(pieriandx_jwt_lambda_collector)

        // Allow only the collector function to read the jwt secret
        // Set the policy for the master secret
        this.deny_all_except_rotator(
            pieriandx_jwt_secret,
            [
                pieriandx_jwt_lambda_collector
            ]
        )

        return [pieriandx_jwt_secret, pieriandx_jwt_lambda_producer]

    }


    private create_event_handling(
        secrets: secretsManager.Secret[],
        slack_host_ssm_name: string,
        slack_webhook_ssm_name: string
    ): PythonFunction {
        /*
        List of secrets we will track for events being rotated
        */

        const slack_event_handling_path = join(__dirname, "../lambdas/slack_notifier")


        // Collect SSM Parameters as objects
        const slack_host_ssm = ssm.StringParameter.fromStringParameterName(
            this,
            "slackHostSSMName",
            slack_host_ssm_name
        )

        const slack_webhook_ssm = ssm.StringParameter.fromSecureStringParameterAttributes(
            this,
            "slackWebHookSSMName",
            {
                parameterName: slack_webhook_ssm_name
            }
        )

        const notifier_lambda_obj = new PythonFunction(
            this,
            "PierianDxSlackNotifier",
            {
                runtime: lambda.Runtime.PYTHON_3_11,
                entry: slack_event_handling_path,
                index: "lambda_entrypoint.py",
                handler: "main",
                timeout: Duration.seconds(60),
                environment: {
                    "SLACK_HOST_SSM_NAME": slack_host_ssm.parameterName,
                    "SLACK_WEBHOOK_SSM_NAME": slack_webhook_ssm.parameterName
                },
                layers: [this.lambda_layer_version_obj]
            }
        );


        // Add Get Parameters to policies
        [
            slack_host_ssm,
            slack_webhook_ssm,
        ].forEach(
            (ssm_obj) => {
                ssm_obj.grantRead(notifier_lambda_obj)
            }
        )


        // Add a rule that traps all the rotation failures for our JWT secrets
        const rule: events.Rule = new events.Rule(
            this,
            "PierianDxJWTNotifySlackRule",
        )

        // Add patterns for RotationFailed and RotationSucceeded
        rule.addEventPattern(
            {
                source: [
                    "aws.secretsmanager"
                ],
                detail: {
                    "eventName": [
                        "RotationFailed",
                    ],
                    "additionalEventData": {
                        "SecretId": secrets.map(
                            (secret_obj) => secret_obj.secretArn
                        )
                    }
                }
            }
        )

        // Add target to rule
        rule.addTarget(
            // @ts-ignore
            new eventsTargets.LambdaFunction(notifier_lambda_obj)
        )

        // Return the lambda notifier
        return notifier_lambda_obj
    }

    private create_ssm_parameter_for_jwt_secret_arn(
        secret_attribute: string,
        key_ssm_path: string,
    ) {
        new ssm.StringParameter(
            this,
            key_ssm_path,
            {
                stringValue: secret_attribute,
                parameterName: key_ssm_path
            }
        )
    }
}



