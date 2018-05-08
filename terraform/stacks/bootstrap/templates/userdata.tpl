#!/bin/bash

# NOTE: externally provided variables:
#       - allocation_id
#       - bucket_name

################################################################################
# TODO: associate our elastic IP with the instance
echo "Associating public IP"
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`cat /var/lib/cloud/data/instance-id`
echo "Instance ID: $instance_id"
echo "Allocation ID: ${allocation_id}"
aws ec2 associate-address --instance-id $instance_id --allocation-id ${allocation_id}


################################################################################
# Running Vault server
echo "Writing Vault config"
sudo tee /opt/vault.cfg << END
storage "s3" {
  bucket = "${bucket_name}"
  region = "ap-southeast-2"
}

listener "tcp" {
 address     = "0.0.0.0:8200"
 tls_disable = 1
}
END

# TODO: restart vault server automatically if it crashes (deamon service)?
echo "Starting Vault server"
vault server -config=/opt/vault.cfg
