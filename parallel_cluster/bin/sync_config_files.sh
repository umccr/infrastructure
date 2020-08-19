#!/usr/bin/env bash

aws s3 sync cromwell/ s3://umccr-temp-dev/Alexis_parallel_cluster_test/cromwell/
aws s3 sync bootstrap/ s3://umccr-temp-dev/Alexis_parallel_cluster_test/bootstrap/
aws s3 sync bcbio s3://umccr-temp-dev/Alexis_parallel_cluster_test/bcbio/