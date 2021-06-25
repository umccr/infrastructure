#!/bin/bash

LAYER_NAME=$1

if test -z "$LAYER_NAME"; then
    echo "LAYER_NAME is not set! Specify the layer for which to create the Lambda package."
    exit 1
fi

# move to the layer we want to build the package for
cd $LAYER_NAME

# spcifiy the lib directory (according to AWS Lambda guidelines)
export PKG_DIR="python"

# clean up any existing files
rm -rf ${PKG_DIR} && mkdir -p ${PKG_DIR}
cp *.* ${PKG_DIR}/

# install the python libraries (without dependencies)
docker run --rm -v $(pwd):/foo -w /foo lambci/lambda:build-python3.8 pip install -r requirements.txt --no-deps -t ${PKG_DIR}

# clean the lib directory
rm -rf ${PKG_DIR}/*.dist-info
find python -type d -name __pycache__ -exec rm -rf {} +

# create the package zip
zip -r $LAYER_NAME.zip ./${PKG_DIR}/

# remove the inflated directory
rm -rf ${PKG_DIR}/