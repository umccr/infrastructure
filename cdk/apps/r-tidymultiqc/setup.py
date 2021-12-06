import setuptools


with open("README.md") as fp:
    long_description = fp.read()


setuptools.setup(
    name="r-tidymultiqc",
    version="0.0.1",

    description="tidyMultiQC on a labmda",
    long_description=long_description,
    long_description_content_type="text/markdown",

    author="Roman Valls Guimera",

    package_dir={"": "aws_lambda_container_cdk_r"},
    packages=setuptools.find_packages(where="aws_lambda_container_cdk_r"),

    install_requires=[
        "aws-cdk.core",
        "aws-cdk.aws_lambda",
    ],

    python_requires=">=3.8",

    classifiers=[
        "Development Status :: 4 - Beta",

        "Intended Audience :: Developers",

        "Programming Language :: JavaScript",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: 3.8",

        "Topic :: Software Development :: Code Generators",
        "Topic :: Utilities",

        "Typing :: Typed",
    ],
)
