#!/bin/bash

# NOTE: externally provided variables:
#       - allocation_id
#       - bucket_name
#       - vault_domain

################################################################################
# TODO: associate our elastic IP with the instance
echo "Associating public IP"
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`cat /var/lib/cloud/data/instance-id`
echo "Instance ID: $instance_id"
echo "Allocation ID: ${allocation_id}"
aws ec2 associate-address --instance-id $instance_id --allocation-id ${allocation_id}


################################################################################
# Retrieve letsencrypt certificate
# Run initial certbot certificate request
certbot-auto certonly --standalone -n -d ${vault_domain} --agree-tos --email florian.reisinger@unimelb.edu.au
echo "Starting letsencrypt renewal service"
sudo systemctl enable letsencrypt
sudo systemctl start letsencrypt

################################################################################
# Run Vault server

echo "Writing Vault config"
sudo tee /opt/vault.hcl << END
storage "s3" {
  bucket = "${bucket_name}"
  region = "ap-southeast-2"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/letsencrypt/live/${vault_domain}/fullchain.pem"
  tls_key_file  = "/etc/letsencrypt/live/${vault_domain}/privkey.pem"
}
END

sudo tee /opt/vault.env << END
CONFIG='/opt/vault.hcl'
OPTIONS=''
END

echo "Starting Vault server"
sudo systemctl enable vault
sudo systemctl start vault
