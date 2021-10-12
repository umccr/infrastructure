import json

from aws_cdk import (
    core,
    aws_ec2 as ec2,
    aws_ecr as ecr,
    aws_ecs as ecs,
    aws_iam as iam,
    aws_ssm as ssm,
    aws_elasticloadbalancingv2 as elbv2,
    aws_route53 as route53,
    aws_route53_targets as route53t,
    aws_certificatemanager as acm,
)


class OntoserverStack(core.Stack):
    def __init__(
        self,
        scope: core.Construct,
        id_: str,
        ontoserver_repo_name: str,
        ontoserver_tag: str,
        dns_record_name: str,
        service_count: int = 1,
        service_memory: int = 2048,
        service_cpu: int = 1024,
        **kwargs,
    ) -> None:
        """
        A stack that spins up a Fargate cluster running Ontoserver with an ALB in-front.

        Args:
            scope:
            id_:
            ontoserver_repo_name:
            ontoserver_tag:
            dns_record_name: The DNS entry to make for the ALB
            service_count: The count of services to spin up behind the ALB in Fargate
            service_memory: The memory assigned to each Fargate instance
            service_cpu: The CPU assigned to each Fargate instance
            **kwargs:
        """
        super().__init__(scope, id_, **kwargs)

        # given the complexity of building our ontoserver image - we don't build here in the CDK, but assume
        # it has been built separately into a repo managed elsewhere
        repo: ecr.Repository = ecr.Repository.from_repository_name(
            self, "Repo", ontoserver_repo_name
        )

        # --- Query deployment env specific config from SSM Parameter Store

        cert_apse2_arn = ssm.StringParameter.from_string_parameter_name(
            self,
            "SSLCertAPSE2ARN",
            # re-using the wildcard as used by htsget.. FIX??
            string_parameter_name="/htsget/acm/apse2_arn",
        )
        cert_apse2 = acm.Certificate.from_certificate_arn(
            self,
            "SSLCertAPSE2",
            certificate_arn=cert_apse2_arn.string_value,
        )

        hosted_zone_id = ssm.StringParameter.from_string_parameter_name(
            self, "HostedZoneID", string_parameter_name="hosted_zone_id"
        )
        hosted_zone_name = ssm.StringParameter.from_string_parameter_name(
            self, "HostedZoneName", string_parameter_name="hosted_zone_name"
        )

        # --- Query main VPC and setup Security Groups

        vpc = ec2.Vpc.from_lookup(
            self,
            "VPC",
            vpc_name="main-vpc",
            tags={
                "Stack": "networking",
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
            description=f"Security Group for ELB in {id_} stack",
            security_group_name=f"{id_} ELB Security Group",
            allow_all_outbound=False,
        )

        sg_ecs_service = ec2.SecurityGroup(
            self,
            "ECSServiceSecurityGroup",
            vpc=vpc,
            description=f"Security Group for ECS Service in {id_} stack",
            security_group_name=f"{id_} ECS Security Group",
        )
        sg_ecs_service.add_ingress_rule(
            peer=sg_elb,
            connection=ec2.Port.tcp(8080),
            description="Allow traffic from Load balancer to ECS service",
        )

        # --- Setup ECS Fargate cluster

        task_execution_role = iam.Role(
            self,
            "ECSTaskExecutionRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
        )
        task_execution_role.add_to_policy(
            iam.PolicyStatement(
                actions=[
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "ssm:GetParameterHistory",
                    "ssm:GetParametersByPath",
                    "ssm:GetParameters",
                    "ssm:GetParameter",
                ],
                resources=["*"],
            )
        )
        task_execution_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name(
                "service-role/AmazonECSTaskExecutionRolePolicy"
            )
        )

        task = ecs.FargateTaskDefinition(
            self,
            f"Task",
            cpu=service_cpu,
            memory_limit_mib=service_memory,
            task_role=task_execution_role,
            execution_role=task_execution_role,
        )

        # the ontoserver docker image we build is built with no security enabled
        # putting this env variable switches on security and enables the FHIR API in read only mode
        ontoserver_settings = {
            "ontoserver": {"security": {"enabled": True, "readOnly": {"fhir": True}}}
        }

        main_container: ecs.ContainerDefinition = task.add_container(
            "Container",
            image=ecs.ContainerImage.from_ecr_repository(
                repository=repo,
                tag=ontoserver_tag,
            ),
            essential=True,
            environment={
                "SPRING_APPLICATION_JSON": json.dumps(
                    ontoserver_settings, separators=(",", ":")
                )
            },
            logging=ecs.LogDriver.aws_logs(
                stream_prefix=f"{id_}",
            ),
        )
        main_container.add_port_mappings(
            ecs.PortMapping(
                container_port=8080,
                protocol=ecs.Protocol.TCP,
            )
        )

        cluster = ecs.Cluster(self, f"Cluster", vpc=vpc)

        service = ecs.FargateService(
            self,
            f"Service",
            platform_version=ecs.FargatePlatformVersion.VERSION1_4,
            task_definition=task,
            cluster=cluster,
            vpc_subnets=private_subnets,
            desired_count=service_count,
            security_groups=[
                sg_ecs_service,
            ],
        )

        # --- Setup Application Load Balancer in front of ECS cluster

        lb = elbv2.ApplicationLoadBalancer(
            self,
            f"ALB",
            vpc=vpc,
            internet_facing=True,
            security_group=sg_elb,
            deletion_protection=False,
        )
        https_listener = lb.add_listener(
            "HttpsLBListener", port=443, certificates=[cert_apse2]
        )
        health_check = elbv2.HealthCheck(
            interval=core.Duration.seconds(60),
            path="/fhir/metadata",
            timeout=core.Duration.seconds(10),
        )
        https_listener.add_targets(
            "LBtoECS",
            port=8080,
            protocol=elbv2.ApplicationProtocol.HTTP,
            targets=[service],
            health_check=health_check,
        )

        # DNS

        hosted_zone = route53.HostedZone.from_hosted_zone_attributes(
            self,
            "HostedZone",
            hosted_zone_id=hosted_zone_id.string_value,
            zone_name=hosted_zone_name.string_value,
        )
        route53.ARecord(
            self,
            "AlbDomainAlias",
            zone=hosted_zone,
            record_name=dns_record_name,
            target=route53.RecordTarget.from_alias(route53t.LoadBalancerTarget(lb)),
        )
