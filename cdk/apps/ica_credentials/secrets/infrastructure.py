import json
import os

from aws_cdk import (
    core as cdk,
    aws_lambda as lambda_,
    aws_iam as iam,
    aws_secretsmanager as secretsmanager,
)
from aws_cdk.core import Duration

from constants import ICA_BASE_URL


class Secrets(cdk.Construct):
    def __init__(self, scope: cdk.Construct, id_: str):
        super().__init__(scope, id_)

        master = self.create_master_secret()

        jwt_producer = self.create_jwt_secret(master)

        cdk.CfnOutput(self, "MasterSecretOutput", export_name="MasterSecretName", value=master.secret_name)
        cdk.CfnOutput(self, "JwtSecretOutput", export_name="JwtSecretName", value=jwt_producer.secret_name)

    def create_master_secret(self) -> secretsmanager.Secret:
        """
        Create the master API key secret - for holding the API key of the master service user.
        This key is only then used by the key rotation lambdas of other secrets.

        Returns:
            the master secret
        """

        # we start the secret with a random value created by secrets manager..
        # first step will be to set this to an API key from Illumina ICA
        master_secret = secretsmanager.Secret(
            self,
            "MasterApiKeySecret",
        )

        return master_secret

    def create_jwt_secret(
        self, master_secret: secretsmanager.Secret
    ) -> secretsmanager.Secret:
        """
        Create a JWT holding secret - that will use the master secret for JWT making - and which will have
        broad permissions to be read by all roles.

        Args:
            master_secret: the master secret to read for the API key for JWT making

        Returns:
            the JWT secret
        """
        dirname = os.path.dirname(__file__)
        filename = os.path.join(dirname, "runtime/jwt_producer/lambda_function.py")

        with open(filename, encoding="utf8") as fp:
            handler_code = fp.read()

            jwt_producer = lambda_.Function(
                self,
                "JwtProducer",
                runtime=lambda_.Runtime.PYTHON_3_8,
                code=lambda_.InlineCode(handler_code),
                handler="index.main",
                environment={
                    "MASTER_ARN": master_secret.secret_arn,
                    "ICA_BASE_URL": ICA_BASE_URL,
                },
                timeout=Duration.seconds(30),
            )

        # we have two ends of the permissions to set
        
        # this end makes the lambda role for JWT producer able to attempt to read the master secret
        master_secret.grant_read(jwt_producer)

        # this end locks down the master secret so that *only* the JWT producer can read values
        # (it is only when we set the DENY policy here that in general other roles in the same account
        #  cannot access the secret value - so it is only after doing that that we need to explicitly enable
        #  the role we do want to access it)
        master_secret.add_to_resource_policy(
            iam.PolicyStatement(
                effect=iam.Effect.DENY,
                actions=["secretsmanager:GetSecretValue"],
                resources=["*"],
                principals=[iam.AccountRootPrincipal()],
                # https://stackoverflow.com/questions/63915906/aws-secrets-manager-resource-policy-to-deny-all-roles-except-one-role
                conditions={
                    "StringNotEquals": {
                        "aws:PrincipalArn": jwt_producer.role.role_arn
                    }
                }
            )
        )
        master_secret.add_to_resource_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=["secretsmanager:GetSecretValue"],
                resources=["*"],
                principals=[jwt_producer.grant_principal],
            )
        )

        # secret itself - no default value as it will eventually get replaced by the JWT
        jwt_secret = secretsmanager.Secret(
            self,
            "JwtSecret",
        )

        # the rotation function that creates JWTs
        jwt_secret.add_rotation_schedule(
            "JwtSecretRotation",
            automatically_after=Duration.days(1),
            rotation_lambda=jwt_producer,
        )

        return jwt_secret
