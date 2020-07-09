#!/bin/bash

# spcifiy the lib directory (according to AWS Lambda guidelines)
export PKG_DIR="python"

# clean up any existing files
rm -rf ${PKG_DIR} && mkdir -p ${PKG_DIR}

# install the python libraries (without dependencies)
docker run --rm -v $(pwd):/foo -w /foo lambci/lambda:build-python3.7 pip install -r requirements.txt --no-deps -t ${PKG_DIR}

# clean the lib directory 
rm -rf ${PKG_DIR}/*.dist-info
find python -type d -name __pycache__ -exec rm -rf {} +

# create the package zip
zip -r python37-pandas.zip ./${PKG_DIR}/

# remove the inflated directory
rm -rf ${PKG_DIR}/