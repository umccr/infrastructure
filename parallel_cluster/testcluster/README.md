# Parallel Cluster playground

## Setup
You can follow the official [docs][install_doc] or [this][blog_1] blog post (section `Setting up your client environment`) to set up the client requirements for parallel cluster.

```bash
conda env update -f pcluster_client.env.yml
```

## Configuration
This configuration expects certain AWS resources to pre-exist, namely:
- a network configuration with `VPC` and `subnet` according to the requirements of Parallel Cluster (the AWS defaults should be OK)
- an instance role `parallelcluster-ec2-instance-role` with appropriate permissions to e.g. access S3 resources, allow SSM login, etc...
- a key pair to be used for SSH

The default configuration may require modifications before it is suitable for your use case. Have a look at the 'config' file and adjust as necessary.

NOTE: See the provided bootstrap script for an example on how to setup the EC2 instances. Note that the config files points to an S3 location!


## Running the cluster

```bash
# Create a cluster called my-test-cluster
(parallel_cluster) ~ $ pcluster create my-test-cluster --config config
Beginning cluster creation for cluster: my-test-cluster
Creating stack named: parallelcluster-my-test-cluster
Status: parallelcluster-my-test-cluster - CREATE_COMPLETE
MasterPublicIP: 3.104.49.154
ClusterUser: ec2-user
MasterPrivateIP: 172.31.23.110
(parallel_cluster) ~ $

# Retrieve IP of Master/Login node
aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId]" \
    --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=Master" \
    | jq -r '.[][][]'

# Login to the master node
(parallel_cluster) ~ $ aws ssm start-session --target <instance ID>

# Delete the cluster when finished
(parallel_cluster) ~ $ pcluster delete my-test-cluster --config config
```

## NOTES

```bash
# Log into the master node with secified SSH key(in case SSM fails)
(parallel_cluster) ~ $ ssh ec2-user@3.104.49.154 -i path/to/private.key
```

## Comments

```bash
# Example for interactive commands (without sinteractive)
srun --time=10:00 --nodes=1 --cpus-per-task=1  --mem=100 --pty -u "/bin/bash" -i -l
```

Slurm default configuration may need customisation. `sacct` does not work, as no default data store is set up.

[install_doc]: https://docs.aws.amazon.com/parallelcluster/latest/ug/install.html
[blog_1]: https://aws.amazon.com/blogs/machine-learning/building-an-interactive-and-scalable-ml-research-environment-using-aws-parallelcluster/


