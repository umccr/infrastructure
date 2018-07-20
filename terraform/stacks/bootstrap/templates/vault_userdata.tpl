#!/bin/bash

# NOTE: externally provided variables:
#       - allocation_id
#       - bucket_name
#       - vault_domain

################################################################################
# associate our elastic IP with the instance
echo "Associating public IP"
export AWS_DEFAULT_REGION=ap-southeast-2
instance_id=`cat /var/lib/cloud/data/instance-id`
echo "Instance ID: $instance_id"
echo "Allocation ID: ${allocation_id}"
aws ec2 associate-address --instance-id $instance_id --allocation-id ${allocation_id}

################################################################################
# tag the instance
aws ec2 create-tags --resources $instance_id --tags Key=Name,Value=vault-dev



################################################################################
# Configure and start certificate manager
echo "Writing certificate manager config"
sudo tee /opt/cert_manager.env << END
VAULT_FQDN="${vault_domain}"
S3_CERT_BACKUP_DIR="s3://${bucket_name}/letsencrypt"
NOTIFY_EMAIL="florian.reisinger@unimelb.edu.au"
END

echo "Starting certificate manager service"
sudo systemctl enable cert_manager.service
sudo systemctl enable cert_manager.timer
sudo systemctl start cert_manager.timer


################################################################################
# Run Vault server

# create the config file for vault
echo "Writing Vault config"
sudo tee /opt/vault.hcl << END
storage "s3" {
  bucket = "${bucket_name}"
  region = "ap-southeast-2"
}

ui = true

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/letsencrypt/live/${vault_domain}/fullchain.pem"
  tls_key_file  = "/etc/letsencrypt/live/${vault_domain}/privkey.pem"
}
END

echo "Starting Vault server"
sudo systemctl enable vault.service
sudo systemctl start vault.service


################################################################################
# Run goldfish server
# create the config file for goldfish
echo "Writing GoldFish config"
sudo tee /opt/goldfish.hcl << END
listener "tcp" {
  address       = ":5000"
  certificate "local" {
    cert_file   = "/etc/letsencrypt/live/${vault_domain}/fullchain.pem"
    key_file    = "/etc/letsencrypt/live/${vault_domain}/privkey.pem"
  }
}
vault {
  address       = "https://${vault_domain}:8200"
}
END

echo "Starting goldfish server"
sudo systemctl enable goldfish.service
sudo systemctl start goldfish.service


################################################################################
# Run token_provider service
echo "Writing token_provider env"
# NOTE: the redirection to /dev/null to silence tee (and not print secrets to STDOUT)
sudo tee /opt/token_provider.env > /dev/null << END
VAULT_ENV="${vault_env}"
VAULT_ADDR="https://${vault_domain}:8200"
VAULT_USER="${tp_vault_user}"
VAULT_PASS="${tp_vault_pass}"
TP_TOKEN_TTL=25h
END


echo "Starting token_provider service"
sudo systemctl enable token_provider.service
sudo systemctl enable token_provider.timer
sudo systemctl start token_provider.timer
