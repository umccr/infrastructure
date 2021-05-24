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
        "aws-cdk-lib",
        "constructs",
    ],

    python_requires=">=3.7",

    classifiers=[
        "Development Status :: 4 - Beta",

        "Intended Audience :: Developers",

        "License :: OSI Approved :: Apache Software License",

        "Programming Language :: JavaScript",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",

        "Topic :: Software Development :: Code Generators",
        "Topic :: Utilities",

        "Typing :: Typed",
    ],
)
