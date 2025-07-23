import {Construct} from 'constructs';
import {AccessKey, AccessKeyStatus, Effect, Policy, PolicyStatement, User} from "aws-cdk-lib/aws-iam";
import {Secret} from "aws-cdk-lib/aws-secretsmanager";
import {CfnOutput, SecretValue, Stack, StackProps} from "aws-cdk-lib";
import {Vpc} from "aws-cdk-lib/aws-ec2";

const IAM_SERIAL = 1;

// Policy statements are from
// https://github.com/seqeralabs/nf-tower-aws/tree/master/forge

export class SeqeraStack extends Stack {
    constructor(scope: Construct, id: string, props?: StackProps) {
        super(scope, id, props);

        const vpc = Vpc.fromLookup(this, "VPC", {

        });

        // we need a seqera user to exist with the correct (limited) permissions
        const user = new User(this, "SeqeraBatchForge", {
            userName: "seqera-batch-forge"
        });

        const forgePolicy = new Policy(this, "SeqeraBatchForgePolicy", {
            policyName: "seqera-batch-forge-policy",
            users: [
                user
            ],
            statements: [
                new PolicyStatement({
                    sid: "Forge",
                    effect: Effect.ALLOW,
                    resources: ["*"],
                    actions: [
                        "ssm:GetParameters",
                        "iam:CreateInstanceProfile",
                        "iam:DeleteInstanceProfile",
                        "iam:GetRole",
                        "iam:RemoveRoleFromInstanceProfile",
                        "iam:CreateRole",
                        "iam:DeleteRole",
                        "iam:AttachRolePolicy",
                        "iam:PutRolePolicy",
                        "iam:AddRoleToInstanceProfile",
                        "iam:PassRole",
                        "iam:DetachRolePolicy",
                        "iam:ListAttachedRolePolicies",
                        "iam:DeleteRolePolicy",
                        "iam:ListRolePolicies",
                        "iam:TagRole",
                        "iam:TagInstanceProfile",
                        "batch:CreateComputeEnvironment",
                        "batch:DescribeComputeEnvironments",
                        "batch:CreateJobQueue",
                        "batch:DescribeJobQueues",
                        "batch:UpdateComputeEnvironment",
                        "batch:DeleteComputeEnvironment",
                        "batch:UpdateJobQueue",
                        "batch:DeleteJobQueue",
                        "fsx:DeleteFileSystem",
                        "fsx:DescribeFileSystems",
                        "fsx:CreateFileSystem",
                        "fsx:TagResource",
                        "ec2:DescribeSecurityGroups",
                        "ec2:DescribeAccountAttributes",
                        "ec2:DescribeSubnets",
                        "ec2:DescribeLaunchTemplates",
                        "ec2:DescribeLaunchTemplateVersions",
                        "ec2:CreateLaunchTemplate",
                        "ec2:DeleteLaunchTemplate",
                        "ec2:DescribeKeyPairs",
                        "ec2:DescribeVpcs",
                        "ec2:DescribeInstanceTypeOfferings",
                        "ec2:GetEbsEncryptionByDefault",
                        "elasticfilesystem:DescribeMountTargets",
                        "elasticfilesystem:CreateMountTarget",
                        "elasticfilesystem:CreateFileSystem",
                        "elasticfilesystem:DescribeFileSystems",
                        "elasticfilesystem:DeleteMountTarget",
                        "elasticfilesystem:DeleteFileSystem",
                        "elasticfilesystem:UpdateFileSystem",
                        "elasticfilesystem:PutLifecycleConfiguration",
                        "elasticfilesystem:TagResource"
                    ]
                })
            ]
        });

        const launchPolicy = new Policy(this, "SeqeraLaunchPolicy", {
            policyName: "seqera-launch-policy",
            users: [
                user
            ],
            statements: [
                new PolicyStatement({
                    sid: "Launch",
                    effect: Effect.ALLOW,
                    resources: ["*"],
                    actions: [
                        "s3:Get*",
                        "s3:List*",
                        "batch:DescribeJobQueues",
                        "batch:CancelJob",
                        "batch:SubmitJob",
                        "batch:ListJobs",
                        "batch:TagResource",
                        "batch:DescribeComputeEnvironments",
                        "batch:TerminateJob",
                        "batch:DescribeJobs",
                        "batch:RegisterJobDefinition",
                        "batch:DescribeJobDefinitions",
                        "ecs:DescribeTasks",
                        "ec2:DescribeInstances",
                        "ec2:DescribeInstanceTypes",
                        "ec2:DescribeInstanceAttribute",
                        "ecs:DescribeContainerInstances",
                        "ec2:DescribeInstanceStatus",
                        "ec2:DescribeImages",
                        "logs:Describe*",
                        "logs:Get*",
                        "logs:List*",
                        "logs:StartQuery",
                        "logs:StopQuery",
                        "logs:TestMetricFilter",
                        "logs:FilterLogEvents",
                        "ses:SendRawEmail"
                    ]
                })
            ]
        });

        const accessKey = new AccessKey(this, "AccessKey", {
            user,
            serial: IAM_SERIAL,
            status: AccessKeyStatus.ACTIVE,
        });

        const secret = new Secret(
            this,
            `SeqeraBatchForgeAccessSecret`,
            {
                description:
                    "Secret containing the access key for an AWS IAM user tied to Seqera",
                secretObjectValue: {
                    accessKeyId: SecretValue.unsafePlainText(accessKey.accessKeyId),
                    secretAccessKey: accessKey.secretAccessKey,
                },
            }
        );

        new CfnOutput(this, "SeqeraUserSecretOutput", {
            exportName: "SeqeraUserSecret",
            value: secret.secretName,
        });

        new CfnOutput(this, "SeqeraVpcOutput", {
            exportName: "SeqeraVpcId",
            value: vpc.vpcId,
        });

    }
}
