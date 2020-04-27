# Parallel Cluster playground

## Cluster Admin

### Setup

You can follow the official [docs][install_doc] or [this][blog_1] blog post (section `Setting up your client environment`) to set up the client requirements for parallel cluster.

```shell
conda env update -f conf/pcluster_client.env.yml
```

This SSM shell function should be added to your `.bashrc` or equivalent:

```shell
ssm() {
    aws ssm start-session --target "$1" --document-name AWS-StartInteractiveCommand --parameters command="sudo su - ec2-user"
}
```

So that logging into the instances becomes:

```bash
$ ssm i-0a13c0c8d3fde0708
```

### Configuration

This configuration expects certain AWS resources to pre-exist, namely:
- a network configuration with `VPC` and `subnet` according to the requirements of Parallel Cluster (the AWS defaults should be OK)
- an instance role `parallelcluster-ec2-instance-role` with appropriate permissions to e.g. access S3 resources, allow SSM login, etc... See AWS managed policies `AmazonSSMManagedInstanceCore` and `AmazonS3ReadOnlyAccess` and policy.json (requires region substitution).
- a key pair to be used for SSH (as admin backup to SSM)

The default configuration (especially EC2 instance types for the compute fleet) may require modifications before it is suitable for your use case. See the `conf/config` file and adjust as necessary.

NOTE: See the provided bootstrap script under `conf/bootstrap.sh` for an example on how to setup the EC2 instances.

### Running the cluster

```shell
$ ./bin/start-cluster.sh <CLUSTER_NAME>
Beginning cluster creation for cluster: my-test-cluster
Creating stack named: parallelcluster-my-test-cluster
Status: parallelcluster-my-test-cluster - CREATE_COMPLETE
MasterPublicIP: 3.104.49.154
ClusterUser: ec2-user
MasterPrivateIP: 172.31.23.110

i-XXXXXXXXX   <---- Master insteance ID

$ ssm i-XXXXXXXXXX

# Delete the cluster when finished
$ ./bin/stop-cluster.sh <CLUSTER_NAME>
```

## Cluster Use

```shell
# Login to the master node
aws ssm start-session --target <instance ID>

# Once on the master node, change into the ec2-user
# (as the environment is setup for that user)
sudo su ec2-user

# Run Slurm commands
sinfo ...
squeue ...
srun ...
sbatch ...
```

Example batch script file
```shell
#!/bin/bash
#SBATCH --output %J.out
#SBATCH --error %J.err
#SBATCH --time=00:05:00

echo 'Foo'
docker run --rm hello-world
```


## Legacy HPC compatible commands 

The bootstrapping installs the `sinteractive` script also used on `Spartan` and it should work in the same way. The Slurm native alternative can be used as well: 

```shell
$ sinteractive --time=10:00 --nodes=1 --cpus-per-task=1
$ srun --time=10:00 --nodes=1 --cpus-per-task=1 --pty -u "/bin/bash" -i -l
```

Eventually, when users are ready to make the transition, this will be migrated to AWS Batch or more modern, efficient and integrated compute scheduling systems.

### Software availability

Software installed on the login node is **not** automatically available on the compute nodes. For software to be avaiable on the cluster it will either have to be installed during the bootstrapping process (which will impact on time it takes for nodes to become available), be used within Docker containers (docker is installed on the cluster) or have to be distributed using a custom AMI that can be used when starting the cluster.

#### Creating a custom AMI

In order to accelerate the bootstrapping process for common software (i.e: R, conda, compilers...) it is recommended to (re)create fresh AMIs. To base off from a fresh Amazon Linux AMI, please check the AMI ID list here and pass it to the `--ami-id` parameter (`alinux` AMIs are preferred for stability).

```shell
$ pcluster createami --ami-id ami-09226b689a5d43824 --os alinux2 --config conf/config --instance-type m5.large --region ap-southeast-2 --cluster-template tothill
```

If all goes whell, the AMI ID will be shown towards the end, ready to put it back on your parallelcluster `config` file:

```shell
$ pcluster createami --ami-id ami-09226b689a5d43824 --os alinux2 --config conf/config --region ap-southeast-2 --cluster-template tothill
Building AWS ParallelCluster AMI. This could take a while...
Base AMI ID: ami-09226b689a5d43824
Base AMI OS: alinux2
Instance Type: t2.xlarge
Region: ap-southeast-2
VPC ID: vpc-7d2b2e1a
Subnet ID: subnet-3ad03d5c
Template: https://s3.ap-southeast-2.amazonaws.com/ap-southeast-2-aws-parallelcluster/templates/aws-parallelcluster-2.6.1.cfn.json
Cookbook: https://s3.ap-southeast-2.amazonaws.com/ap-southeast-2-aws-parallelcluster/cookbooks/aws-parallelcluster-cookbook-2.6.1.tgz
Packer log: /var/folders/wz/__dd9trs0kl4jb3rs83704y80000gn/T/packer.log.20200427-145000.vaipm3lx
Packer Instance ID: i-04a763679c1439fc3
Packer status: 	exit code 0

Custom AMI ami-0b01adf2b53dcfe7c created with name custom-ami-aws-parallelcluster-2.6.1-amzn2-hvm-202004271450

To use it, add the following variable to the AWS ParallelCluster config file, under the [cluster ...] section
custom_ami = ami-0b01adf2b53dcfe7c
```

### File System

The cluster uses EFS to provide a scalable FS that is available to all nodes. This means that all compute nodes have access to the same FS and don't necessarily have to stage their own data (if it was already put in place). However, that also means the data put into EFS remains avaiable (and chargeable) as long as the cluster remains. So data will have to be cleaned up manually after it fulfilled it's purpose.

### Limitations

The current cluster and scheduler (Slurm) run with minimal configuration, so there will be some limitations. Known points include:

- Slurm's accounting (`sacct`) is not supported, as it requires an accounting data store to be set up.
- `--mem` option may cause a job to fail with `Requested node configuration is not available`

[install_doc]: https://docs.aws.amazon.com/parallelcluster/latest/ug/install.html
[blog_1]: https://aws.amazon.com/blogs/machine-learning/building-an-interactive-and-scalable-ml-research-environment-using-aws-parallelcluster/
