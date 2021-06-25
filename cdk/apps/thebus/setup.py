import setuptools

with open("README.md") as fp:
    long_description = fp.read()

setuptools.setup(
    name="thebus",
    version="0.0.1",

    description="CDK Python app for deploying UMCCR event bus system",
    long_description=long_description,
    long_description_content_type="text/markdown",

    author="UMCCR",

    install_requires=[
        "boto3",
        "aws-cdk-lib",
        "constructs",
        # "aws_solutions_constructs.aws_sqs_lambda"
        # "aws_cdk.aws_lambda_python"
    ],

    python_requires=">=3.8",

    classifiers=[
        "Development Status :: 4 - Beta",

        "Intended Audience :: Developers",

        "License :: OSI Approved :: Apache Software License",

        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: 3.8",

        "Topic :: Software Development :: Code Generators",
        "Topic :: Utilities",

        "Typing :: Typed",
    ],
)
