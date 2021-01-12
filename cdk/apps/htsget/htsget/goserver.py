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
)


class GoServerStack(core.Stack):

    def __init__(self, scope: core.Construct, id_: str, props, **kwargs) -> None:
        super().__init__(scope, id_, **kwargs)

        namespace = props['namespace']
        htsget_refserver_ecr_repo: ecr.Repository = props['ecr_repo']
        htsget_refserver_image_tag = props['htsget_refserver_image_tag']
        cors_allowed_origins = props['cors_allowed_origins']

        # ---

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

        # ---

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

        # ---

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

        vpc_link = apigwv2.VpcLink(
            self,
            f"{namespace}-VpcLink",
            vpc=vpc,
            security_groups=[sg_ecs_service, sg_elb, ]
        )
        custom_domain = apigwv2.DomainName(
            self,
            "CustomDomain",
            certificate=cert_apse2,
            domain_name=domain_name.string_value,
        )
        http_api = apigwv2.HttpApi(
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
        http_api.add_routes(
            methods=[apigwv2.HttpMethod.ANY],
            path="/{proxy+}",
            integration=apigwv2i.HttpAlbIntegration(
                listener=listener,
                vpc_link=vpc_link,
            ),
        )
        core.CfnOutput(
            self,
            "ApiEndpoint",
            value=http_api.api_endpoint
        )

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
