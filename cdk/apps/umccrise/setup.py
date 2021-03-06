import setuptools


with open("README.md") as fp:
    long_description = fp.read()


setuptools.setup(
    name="umccrise_cdk",
    version="0.0.1",

    description="An CDK Python app to deploy the stack for UMCCRise",
    long_description=long_description,
    long_description_content_type="text/markdown",

    author="author",

    package_dir={"": "stacks"},
    packages=setuptools.find_packages(where="stacks"),

    install_requires=[
        "aws_cdk.aws_batch",
        "aws_cdk.aws_codebuild",
        "aws_cdk.aws_codecommit",
        "aws_cdk.aws_codepipeline",
        "aws_cdk.aws_ec2",
        "aws_cdk.aws_ecs",
        "aws_cdk.aws_ecr",
        "aws_cdk.aws_events_targets",
        "aws_cdk.aws_iam",
        "aws_cdk.aws_lambda",
        "aws_cdk.aws_s3",
        "aws_cdk.aws_s3_assets",
        "aws_cdk.aws_ssm",
        "aws-cdk.core",
        "boto3"
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

        "Topic :: Software Development :: Code Generators",
        "Topic :: Utilities",

        "Typing :: Typed",
    ],
)
