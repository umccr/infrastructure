import {Construct} from 'constructs';
import {RotationSchedule, Secret} from "aws-cdk-lib/aws-secretsmanager";
import {AssetCode, Function, Runtime} from 'aws-cdk-lib/aws-lambda'
import {join} from "path";
import {AccountRootPrincipal, Effect, FederatedPrincipal, PolicyStatement, Role} from "aws-cdk-lib/aws-iam";
import {aws_iam, Duration, Stack, StackProps} from "aws-cdk-lib";
import {IStringParameter, StringParameter} from "aws-cdk-lib/aws-ssm";
import {Rule} from "aws-cdk-lib/aws-events";
import {LambdaFunction} from "aws-cdk-lib/aws-events-targets";
import {OpenIdConnectProvider} from "aws-cdk-lib/aws-eks";

import {GITHUB_DOMAIN} from "../bin/icav2_credentials"

// import * as sqs from 'aws-cdk-lib/aws-sqs';
interface Icav2CredentialsStackProps extends StackProps {
    icav2_base_url: string,
    key_name: string,
    slack_host_ssm_name: string,
    slack_webhook_ssm_name: string,
    github_repos?: string[],
    github_role_name?: string | null
    env: {
        account: string
        region: string
    },

}

export class Icav2CredentialsStack extends Stack {
    private props: Icav2CredentialsStackProps

    constructor(scope: Construct, id: string, props: Icav2CredentialsStackProps) {
        super(scope, id, props);

        // Collect the properties of this stack object
        this.props = props

        // Create the master secret (we will update this with the actual api key later on)
        const master_secret: Secret = this.create_master_secret(props.key_name)

        // Create the jwt token and rotator function
        const [jwt_secret, jwt_func]: [Secret, Function] = this.create_jwt_secret(
            master_secret,
            props.icav2_base_url,
            props.key_name,
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
            this.props.slack_host_ssm_name,
            this.props.slack_webhook_ssm_name
        )

        // Add OIDC for GitHub
        this.share_jwt_secret_with_github_actions_repo(
            jwt_secret,
            this.props.github_repos,
            this.props.github_role_name
        )

    }

    private create_master_secret(key_name: string): Secret {
        /*
        Create the API key for this secret
        */

        let master_api_key_secret: Secret;
        master_api_key_secret = new Secret(
            this,
            `ICAv2ApiKey${key_name}`,
            {
                description: "Master ICAv2 API Key - not for direct use - use corresponding JWT secrets instead"
            }
        );

        return master_api_key_secret
    }

    private deny_all_except_rotator(
        master_secret: Secret,
        rotator_functions: Function[]  // In the event that we need to create multiple JWTs from the same secret
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
        master_secret.addToResourcePolicy(
            new PolicyStatement({
                    effect: Effect.DENY,
                    actions: ["secretsmanager:GetSecretValue"],
                    resources: ["*"],  // No resources allowed by default
                    principals: [new AccountRootPrincipal()],
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
        master_secret: Secret,
        ica_base_url: string,
        key_name: string
    ): [Secret, Function] {

        const jwt_lambda_path = join(__dirname, "../lambdas/icav2_jwt_producer")

        const icav2_jwt_lambda_producer = new Function(
            this,
            `ICAv2JwtProducer${key_name}`,
            {
                runtime: Runtime.PYTHON_3_10,
                code: new AssetCode(jwt_lambda_path),
                handler: "lambda_entrypoint.main",
                timeout: Duration.seconds(60),  // Magic
                environment: {
                    "ICAV2_BASE_URL": ica_base_url,
                    "API_KEY_AWS_SECRETS_MANAGER_ARN": master_secret.secretArn
                }
            }
        )

        // Give the newly created lambda object instant access to the api key
        // Note we update the permissions in a later step
        master_secret.grantRead(icav2_jwt_lambda_producer)

        // Generate the secret now
        let icav2_jwt_secret: Secret = new Secret(
            this,
            `ICAv2Jwt${key_name}`,
            {
                secretName: `ICAv2Jwt${key_name}`,
                description: "JWT providing access to ICAv2 projects"
            }
        )

        // Add rotation schedule
        const rotation_schedule = new RotationSchedule(
            this,
            'JwtICAv2SecretRotation', {
                secret: icav2_jwt_secret,
                // the properties below are optional
                automaticallyAfter: Duration.hours(48),
                rotationLambda: icav2_jwt_lambda_producer
            }
        );

        return [icav2_jwt_secret, icav2_jwt_lambda_producer]

    }

    private create_event_handling(
        secrets: Secret[],
        slack_host_ssm_name: string,
        slack_webhook_ssm_name: string
    ): Function {
        /*
        List of secrets we will track for events being rotated
        */

        const slack_event_handling_path = join(__dirname, "../lambdas/slack_notifier")


        // Collect SSM Parameters as objects
        const slack_host_ssm: IStringParameter = StringParameter.fromStringParameterName(
            this,
            "slackHostSSMName",
            slack_host_ssm_name
        )
        const slack_webhook_ssm: IStringParameter = StringParameter.fromSecureStringParameterAttributes(
            this,
            "slackWebHookSSMName",
            {
                parameterName: slack_webhook_ssm_name
            }
        )

        let notifier: Function = new Function(
            this,
            "ICAv2JWTNotifySlack",
            {
                runtime: Runtime.PYTHON_3_10,
                code: new AssetCode(slack_event_handling_path),
                handler: "lambda_entrypoint.main",
                timeout: Duration.seconds(60),  // MAGIC
                environment: {
                    "SLACK_HOST_SSM_NAME": slack_host_ssm.parameterName,
                    "SLACK_WEBHOOK_SSM_NAME": slack_webhook_ssm.parameterName
                }
            }
        )


        // Add Get Parameters to policies
        notifier.addToRolePolicy(
            new PolicyStatement(
                {
                    actions: [
                        "ssm:GetParameter"
                    ],
                    resources: [
                        slack_host_ssm.parameterArn,
                        slack_webhook_ssm.parameterArn
                    ],
                }
            )
        )

        // Add a rule that traps all the rotation failures for our JWT secrets
        const rule: Rule = new Rule(
            this,
            "ICAv2JWTNotifySlackRule",
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
                        "RotationSucceeded"
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
            new LambdaFunction(notifier)
        )

        // Return the lambda notifier
        return notifier
    }

    // Note this is setting up a 1-1 mapping between roles and secrets
    // If a user needs multiple JWT secrets for a given repo, they will need to assume multiple roles
    private share_jwt_secret_with_github_actions_repo(
        secret: Secret,
        github_repositories?: string[] | null,
        role_name?: string | null
    ) {

        if (github_repositories === undefined || github_repositories === null || github_repositories.length === 0){
            console.log("No GitHub repositories to add this role to")
            return
        }

        if (role_name === undefined || role_name === null){
            console.log("Role name undefined")
            return
        }
        
        // Set role
        const gh_action_role = new Role(
            this,
            role_name, {
                assumedBy: new FederatedPrincipal(
                    `arn:aws:iam::${this.props.env.account}:oidc-provider/token.actions.githubusercontent.com`,
                    {
                        StringEquals: {
                            'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
                        },
                        StringLike: {
                            'token.actions.githubusercontent.com:sub': github_repositories.join(",")
                        }
                    },
                    'sts:AssumeRoleWithWebIdentity',
                ),
            }
        );

        // Add permissions to role
        gh_action_role.addToPolicy(
            new PolicyStatement(
                {
                    actions: [
                        "secretsManager:GetSecretValue"
                    ],
                    resources: [
                        secret.secretArn
                    ]
                }
            )
        )
    }
}
