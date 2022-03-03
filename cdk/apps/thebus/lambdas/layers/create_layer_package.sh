#!/bin/bash

LAYER_NAME=$1

if test -z "$LAYER_NAME"; then
    echo "LAYER_NAME is not set! Specify the layer for which to create the Lambda package."
    exit 1
fi

# spcifiy the lib directory (according to AWS Lambda guidelines)
export PKG_DIR="python"

# clean up any existing files
rm ${LAYER_NAME}.zip
rm -rf ${PKG_DIR}
cp -R ${LAYER_NAME}/ ${PKG_DIR}/

# install the python libraries (without dependencies)
docker run --rm -v $(pwd)/${PKG_DIR}:/foo -w /foo lambci/lambda:build-python3.8 pip install -r requirements.txt --no-deps -t ./

# clean the lib directory
rm -rf ${PKG_DIR}/*.dist-info
find python -type d -name __pycache__ -exec rm -rf {} +

# create the package zip
zip -r ${LAYER_NAME}.zip ./${PKG_DIR}/

# remove the inflated directory
rm -rf ${PKG_DIR}/