#!/bin/bash

set -e

repo_tag=$1
if [ -z "$repo_tag" ]; then
  echo "To build an AMI exactly one git tag is required. Skipping build..."
  exit 0
fi

echo "Building with tag $repo_tag"

echo "Parse tag to see which AMI to build"
