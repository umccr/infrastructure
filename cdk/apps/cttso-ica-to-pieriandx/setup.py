import setuptools


with open("README.md") as fp:
    long_description = fp.read()


setuptools.setup(
    name="cttso_ica_to_pieriandx",
    version="0.0.1",

    description="An empty CDK Python app",
    long_description=long_description,
    long_description_content_type="text/markdown",

    author="author",

    package_dir={"": "cttso_ica_to_pieriandx"},
    packages=setuptools.find_packages(where="cttso_ica_to_pieriandx"),

    install_requires=[
        "aws-cdk-lib==2.0.0-rc.27",
        "boto3",
        "constructs>=10.0.0,<11.0.0",
    ],

    python_requires=">=3.6",

    classifiers=[
        "Development Status :: 4 - Beta",

        "Intended Audience :: Developers",

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
