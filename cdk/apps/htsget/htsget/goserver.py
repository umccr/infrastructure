import os

import docker
from aws_cdk import (
    core,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_ecr as ecr,
    aws_iam as iam,
    aws_ssm as ssm,
    aws_route53 as route53,
    aws_route53_targets as route53t,
    aws_certificatemanager as acm,
    aws_elasticloadbalancingv2 as elbv2,
    aws_apigatewayv2 as apigwv2,
    aws_apigatewayv2_integrations as apigwv2i,
    aws_lambda as lmbda,
)


class GoServerStack(core.Stack):

    def __init__(self, scope: core.Construct, id_: str, props, **kwargs) -> None:
        super().__init__(scope, id_, **kwargs)

        namespace = props['namespace']
        htsget_refserver_ecr_repo: ecr.Repository = props['ecr_repo']
        htsget_refserver_image_tag = props['htsget_refserver_image_tag']
        cors_allowed_origins = props['cors_allowed_origins']

        # --- Query deployment env specific config from SSM Parameter Store

        cert_apse2_arn = ssm.StringParameter.from_string_parameter_name(
            self,
            "SSLCertAPSE2ARN",
            string_parameter_name="/htsget/acm/apse2_arn",
        )
        cert_apse2 = acm.Certificate.from_certificate_arn(
            self,
            "SSLCertAPSE2",
            certificate_arn=cert_apse2_arn.string_value,
        )

        hosted_zone_id = ssm.StringParameter.from_string_parameter_name(
            self,
            "HostedZoneID",
            string_parameter_name="hosted_zone_id"
        )
        hosted_zone_name = ssm.StringParameter.from_string_parameter_name(
            self,
            "HostedZoneName",
            string_parameter_name="hosted_zone_name"
        )

        domain_name = ssm.StringParameter.from_string_parameter_name(
            self,
            "DomainName",
            string_parameter_name="/htsget/domain",
        )

        # --- Query main VPC and setup Security Groups

        vpc = ec2.Vpc.from_lookup(
            self,
            "VPC",
            vpc_name="main-vpc",
            tags={
                'Stack': "networking",
            },
        )
        private_subnets = ec2.SubnetSelection(
            subnet_type=ec2.SubnetType.PRIVATE,
            availability_zones=["ap-southeast-2a"],
        )

        sg_elb = ec2.SecurityGroup(
            self,
            "ELBSecurityGroup",
            vpc=vpc,
            description=f"Security Group for ELB in {namespace} stack",
            security_group_name=f"{namespace} ELB Security Group",
            allow_all_outbound=False,
        )
        sg_elb.add_ingress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.tcp(80),
            description="Allow http inbound within VPC"
        )

        sg_ecs_service = ec2.SecurityGroup(
            self,
            "ECSServiceSecurityGroup",
            vpc=vpc,
            description=f"Security Group for ECS Service in {namespace} stack",
            security_group_name=f"{namespace} ECS Security Group",
        )
        sg_ecs_service.add_ingress_rule(
            peer=sg_elb,
            connection=ec2.Port.tcp(3000),
            description="Allow traffic from Load balancer to ECS service"
        )

        # --- Setup ECS Fargate cluster

        config_vol = ecs.Volume(
            name="config-vol",
            host=ecs.Host(),
        )

        task_execution_role = iam.Role(
            self,
            "ecsTaskExecutionRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com")
        )
        task_execution_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "ssm:GetParameterHistory",
                    "ssm:GetParametersByPath",
                    "ssm:GetParameters",
                    "ssm:GetParameter",
                ],
                resources=["*"],
            )
        )
        task_execution_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name('service-role/AmazonECSTaskExecutionRolePolicy')
        )

        task = ecs.FargateTaskDefinition(
            self,
            f"{namespace}-task",
            cpu=512,
            memory_limit_mib=1024,
            volumes=[config_vol],
            task_role=task_execution_role,
            execution_role=task_execution_role,
        )

        cmd_ssm = "ssm get-parameter --name '/htsget/refserver/config' --output text --query Parameter.Value"
        sidecar_container: ecs.ContainerDefinition = task.add_container(
            f"{namespace}-sidecar",
            image=ecs.ContainerImage.from_registry("quay.io/victorskl/aws-cli:2.1.3"),
            essential=False,
            entry_point=["/bin/bash", "-c", f"aws {cmd_ssm} > config.json", ],
            logging=ecs.LogDriver.aws_logs(stream_prefix=f"{namespace}", ),
        )
        sidecar_container.add_mount_points(
            ecs.MountPoint(
                container_path="/aws",
                read_only=False,
                source_volume=config_vol.name,
            )
        )

        main_container: ecs.ContainerDefinition = task.add_container(
            namespace,
            image=ecs.ContainerImage.from_ecr_repository(
                repository=htsget_refserver_ecr_repo,
                tag=htsget_refserver_image_tag,
            ),
            essential=True,
            command=["./htsget-refserver", "-config", "/usr/src/app/config/config.json"],
            logging=ecs.LogDriver.aws_logs(stream_prefix=f"{namespace}", ),
        )
        main_container.add_port_mappings(
            ecs.PortMapping(
                container_port=3000,
                protocol=ecs.Protocol.TCP,
            )
        )
        main_container.add_mount_points(
            ecs.MountPoint(
                container_path="/usr/src/app/config",
                read_only=True,
                source_volume=config_vol.name,
            )
        )
        main_container.add_container_dependencies(
            ecs.ContainerDependency(
                container=sidecar_container,
                condition=ecs.ContainerDependencyCondition.COMPLETE,
            )
        )

        cluster = ecs.Cluster(self, f"{namespace}-cluster", vpc=vpc)

        service = ecs.FargateService(
            self,
            f"{namespace}-service",
            platform_version=ecs.FargatePlatformVersion.VERSION1_4,
            task_definition=task,
            cluster=cluster,
            vpc_subnets=private_subnets,
            desired_count=1,
            security_groups=[sg_ecs_service, ],
        )

        # --- Setup Application Load Balancer in front of ECS cluster

        lb = elbv2.ApplicationLoadBalancer(
            self,
            f"{namespace}-lb",
            vpc=vpc,
            internet_facing=False,
            security_group=sg_elb,
        )
        listener = lb.add_listener(
            "LBListener",
            port=80,
        )
        health_check = elbv2.HealthCheck(
            interval=core.Duration.seconds(30),
            path="/reads/service-info",
            timeout=core.Duration.seconds(5)
        )
        listener.add_targets(
            "LBtoECS",
            port=3000,
            protocol=elbv2.ApplicationProtocol.HTTP,
            targets=[service],
            health_check=health_check,
        )
        core.CfnOutput(
            self,
            "LoadBalancerDNS",
            value=lb.load_balancer_dns_name
        )

        # --- Setup APIGatewayv2 HttpApi using VpcLink private integration to ALB/ECS in private subnets

        vpc_link = apigwv2.VpcLink(
            self,
            f"{namespace}-VpcLink",
            vpc=vpc,
            security_groups=[sg_ecs_service, sg_elb, ]
        )
        self.apigwv2_alb_integration = apigwv2i.HttpAlbIntegration(
            listener=listener,
            vpc_link=vpc_link,
        )
        custom_domain = apigwv2.DomainName(
            self,
            "CustomDomain",
            certificate=cert_apse2,
            domain_name=domain_name.string_value,
        )
        self.http_api = apigwv2.HttpApi(
            self,
            f"{namespace}-apigw",
            default_domain_mapping=apigwv2.DefaultDomainMappingOptions(domain_name=custom_domain),
            cors_preflight=apigwv2.CorsPreflightOptions(
                allow_origins=cors_allowed_origins,
                allow_headers=["*"],
                allow_methods=[
                    apigwv2.HttpMethod.GET,
                    apigwv2.HttpMethod.OPTIONS,
                    apigwv2.HttpMethod.HEAD,
                    apigwv2.HttpMethod.DELETE,
                    apigwv2.HttpMethod.POST,
                    apigwv2.HttpMethod.PUT,
                    apigwv2.HttpMethod.PATCH,
                ],
                allow_credentials=True,
            )
        )
        core.CfnOutput(
            self,
            "ApiEndpoint",
            value=self.http_api.api_endpoint
        )

        # --- Setup DNS for the custom domain

        hosted_zone = route53.HostedZone.from_hosted_zone_attributes(
            self,
            "HostedZone",
            hosted_zone_id=hosted_zone_id.string_value,
            zone_name=hosted_zone_name.string_value,
        )
        route53.ARecord(
            self,
            "ApiCustomDomainAlias",
            zone=hosted_zone,
            record_name="htsget",
            target=route53.RecordTarget.from_alias(
                route53t.ApiGatewayv2Domain(domain_name=custom_domain)
            ),
        )
        core.CfnOutput(
            self,
            "HtsgetEndpoint",
            value=custom_domain.name,
        )

        # Add catch all routes
        rt_catchall = apigwv2.HttpRoute(
            self,
            "CatchallRoute",
            http_api=self.http_api,
            route_key=apigwv2.HttpRouteKey.with_(
                path="/{proxy+}",
                method=apigwv2.HttpMethod.ANY
            ),
            integration=self.apigwv2_alb_integration
        )
        rt_catchall_cfn: apigwv2.CfnRoute = rt_catchall.node.default_child
        rt_catchall_cfn.authorization_type = "AWS_IAM"

        # Comment this to opt-out setting up experimental Passport + htsget
        self.setup_ga4gh_passport()

    def setup_ga4gh_passport(self):
        """Experimental setup for GA4GH Passport + htsget

        This add lambda function as authorizer hook into ApiGatewayv2 HttpApi.

        Lambda function implements GA4GH Passport Clearinghouse -- claims verification logic -- to decide
        whether to allow the said claim to pass access htsget endpoint or, deny otherwise.
        """

        # --- Setup Authz lambda function that implement GA4GH Passport Clearinghouse component

        function_name = "htsget_passport_authz_lambda"
        lmbda_deps_file = "lambdas/requirements.txt"
        lmbda_deps_out = f"lambdas/.build/{function_name}"

        # Setup Python dependencies as Lambda layer
        if not os.path.exists(lmbda_deps_out):
            dkr_client = docker.from_env()
            dkr_image = dkr_client.images.pull(repository="lambci/lambda", tag="build-python3.8")
            cmd = f"pip install -r {lmbda_deps_file} -t {lmbda_deps_out}/python"
            dkr_client.containers.run(
                image=dkr_image.tags[0],
                command=cmd,
                auto_remove=True,
                volumes={
                    os.getcwd(): {
                        'bind': "/var/task",
                        'mode': "rw",
                    },
                }
            )

        authzr_func = lmbda.Function(
            self,
            "PassportAuthzLambda",
            function_name=function_name,
            handler="ppauthz.handler",
            runtime=lmbda.Runtime.PYTHON_3_8,
            code=lmbda.Code.from_asset("lambdas/ppauthz"),
            timeout=core.Duration.seconds(20),
            layers=[
                lmbda.LayerVersion(
                    self,
                    "PassportAuthzLambdaDeps",
                    code=lmbda.Code.from_asset(lmbda_deps_out)
                )
            ]
        )

        # --- Setup GA4GH Passport ApiGatewayv2 Authorizer

        authzr_uri = f"arn:aws:apigateway:{self.region}:lambda:path/2015-03-31/functions/" \
                     f"{authzr_func.function_arn}/invocations"

        authzr = apigwv2.CfnAuthorizer(
            self,
            "PassportAuthorizer",
            api_id=self.http_api.http_api_id,
            authorizer_type="REQUEST",
            authorizer_uri=authzr_uri,
            authorizer_result_ttl_in_seconds=300,
            authorizer_payload_format_version="2.0",
            identity_source=[
                "$request.header.Authorization",
            ],
            enable_simple_responses=True,
            name="PassportAuthorizer",
        )

        authzr_arn = f"arn:aws:execute-api:{self.region}:{self.account}:" \
                     f"{self.http_api.http_api_id}/authorizers/{authzr.ref}"
        core.CfnOutput(
            self,
            "PassportAuthorizerArn",
            value=authzr_arn
        )

        # Allow ApiGatewayv2 to invoke authz lambda function
        authzr_func.add_permission(
            "ApiGatewayInvokePermission",
            principal=iam.ServicePrincipal("apigateway.amazonaws.com"),
            action="lambda:InvokeFunction",
            source_arn=authzr_arn,
        )

        # --- Add protected endpoint routes in ApiGatewayv2 HttpApi for secured data serving with htsget backend!

        # Add route protected with GA4GH Passport
        rt_protected_pp = apigwv2.HttpRoute(
            self,
            "PassportProtectedRoute",
            http_api=self.http_api,
            route_key=apigwv2.HttpRouteKey.with_(
                path="/reads/giab.NA12878.NIST7086.2",
                method=apigwv2.HttpMethod.ANY
            ),
            integration=self.apigwv2_alb_integration
        )
        rt_protected_pp_cfn: apigwv2.CfnRoute = rt_protected_pp.node.default_child
        rt_protected_pp_cfn.authorizer_id = authzr.ref
        rt_protected_pp_cfn.authorization_type = "CUSTOM"
