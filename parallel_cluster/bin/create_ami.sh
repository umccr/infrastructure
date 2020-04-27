#!/bin/sh

check_prereqs() {
	# XXX: check if berks is installed, see:
	# https://github.com/aws/aws-parallelcluster/issues/1745
}

# XXX: Parametrize AMI-ID, depending on fresh-new releases+provisioning (preferred) or based on existing "AMI lineage" (discouraged)
echo "Creating AMI"
pcluster createami --ami-id ami-09226b689a5d43824 --os alinux2 --config conf/config --region ap-southeast-2 --cluster-template tothill
