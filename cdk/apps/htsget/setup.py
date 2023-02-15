import setuptools

with open("README.md") as fp:
    long_description = fp.read()

setuptools.setup(
    name="htsget",
    version="0.0.1",

    description="CDK Python app for deploying htsget-refserver",
    long_description=long_description,
    long_description_content_type="text/markdown",

    author="UMCCR",

    package_dir={"": "htsget"},
    packages=setuptools.find_packages(where="htsget"),

    install_requires=[
        "docker",
        # deprecation note:
        # - pinned last known working CDK v1 versions as deprecating this stack
        # - this stack has been completely tear down from both DEV and PROD
        # - commented out dependencies to avoid dependabot such as #278
        # "aws-cdk.core==1.128.0",
        # "aws-cdk.aws_ec2==1.128.0",
        # "aws-cdk.aws_ecs==1.128.0",
        # "aws-cdk.aws_ecr==1.128.0",
        # "aws-cdk.aws_iam==1.128.0",
        # "aws_cdk.aws_ssm==1.128.0",
        # "aws_cdk.aws_route53==1.128.0",
        # "aws_cdk.aws_route53_targets==1.128.0",
        # "aws-cdk.aws_certificatemanager==1.128.0",
        # "aws-cdk.aws_elasticloadbalancingv2==1.128.0",
        # "aws-cdk.aws_apigatewayv2==1.128.0",
        # "aws-cdk.aws_apigatewayv2_integrations==1.128.0",
        # "aws-cdk.aws_lambda==1.128.0",
    ],

    python_requires=">=3.6",

    classifiers=[
        "Development Status :: 4 - Beta",

        "Intended Audience :: Developers",

        "License :: OSI Approved :: Apache Software License",

        "Programming Language :: JavaScript",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",

        "Topic :: Software Development :: Code Generators",
        "Topic :: Utilities",

        "Typing :: Typed",
    ],
)
