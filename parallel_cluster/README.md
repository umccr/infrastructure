# UMCCR's AWS Parallel Cluster

[AWS Parallel cluster][aws_parallel_cluster] is a Cloud-HPC system designed to bring traditional HPC practices to the cloud. UMCCR's intent is to onboard users to AWS, first on HPC and then steadily transitioning to more cloud-native, efficient alternatives where suitable.

## Cluster Admin

### Setup

The [`conf/pcluster_client.env.yml` mentioned below][conda_conf] will setup `aws-parallelcluster` and other python dependencies on your python virtual environment. At UMCCR we typically use [Miniconda][miniconda], please set it up if you have not already before continuing.

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

In order to accelerate the bootstrapping process for common software (i.e: R, conda, compilers...) it is recommended to (re)create fresh AMIs. To base off from a fresh Amazon Linux 2 AMI. [The EC2 Image builder eases this process significantly](https://aws.amazon.com/image-builder/):

![ec2builder2](img/build_bioinfo_component.png)
![ec2builder1](img/bioinformatics_component.png)
![ec2builder4](img/several_components.png)

To use the newly created AMI, just add the following variable to the AWS ParallelCluster config file, under the [cluster ...] section, i.e:

```
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
[aws_parallel_cluster]: https://aws.amazon.com/hpc/parallelcluster/
[miniconda]: https://docs.conda.io/en/latest/miniconda.html
[conda_conf]: https://github.com/umccr/infrastructure/blob/master/parallel_cluster/conf/pcluster_client.env.yml
