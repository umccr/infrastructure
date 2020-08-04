# UMCCR's AWS Parallel Cluster

[AWS Parallel cluster][aws_parallel_cluster] is a Cloud-HPC system designed to bring traditional HPC practices to the cloud.

UMCCR's intent is to onboard users to AWS, first on HPC and then steadily **transitioning to more cloud-native, efficient alternatives where suitable. This includes but is not limited to Illumina Access Platform (IAP).**

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
$ ssm i-XXXXXXXXXXXXX
```

### Running the cluster

```shell
$ ./bin/start-cluster.sh <CLUSTER_NAME>
Beginning cluster creation for cluster: my-test-cluster
Creating stack named: parallelcluster-my-test-cluster
Status: parallelcluster-my-test-cluster - CREATE_COMPLETE
MasterPublicIP: 3.104.49.154
ClusterUser: ec2-user
MasterPrivateIP: 172.31.23.110

i-XXXXXXXXX   <---- Master instance ID

$ ssm i-XXXXXXXXXX

# Delete the cluster when finished
$ ./bin/stop-cluster.sh <CLUSTER_NAME>
```

## Cluster Use

```shell
# Login to the master node
ssm <instance ID>

# Run Slurm commands as usual
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

#### Installing new software on the cluster

Refer to [the custom AMI README.md](ami/README.md) to include your own (bioinformatics) software.

### File System

The cluster uses EFS to provide a **filesystem that is available to all nodes**. This means that all compute nodes have access to the same FS and don't necessarily have to stage their own data (if it was already put in place). However, that also means the data put into EFS remains avaiable (and chargeable) as long as the cluster remains. So data will have to be cleaned up manually after it fulfilled it's purpose.

This cluster also **uses AWS FSx lustre to access UMCCR "data lakes" or S3 buckets** where all the research data resides. Those S3 buckets are made available through:

```
/mnt/refdata (mapping s3://umccr-refdata-dev for all genomics reference data)
/mnt/primary-data (mapping to s3://umccr-temp-dev for input datasets)
```

Those mountpoints are subject to change, this is a work in progress that requires human consensus.

### Limitations

The current cluster and scheduler (SLURM) run with minimal configuration, so there will be some limitations. Known points include:

- Slurm's accounting (`sacct`) is not supported, as it requires an accounting data store to be set up.
- `--mem` option may cause a job to fail with `Requested node configuration is not available`

[install_doc]: https://docs.aws.amazon.com/parallelcluster/latest/ug/install.html
[blog_1]: https://aws.amazon.com/blogs/machine-learning/building-an-interactive-and-scalable-ml-research-environment-using-aws-parallelcluster/
[aws_parallel_cluster]: https://aws.amazon.com/hpc/parallelcluster/
[miniconda]: https://docs.conda.io/en/latest/miniconda.html
[conda_conf]: https://github.com/umccr/infrastructure/blob/master/parallel_cluster/conf/pcluster_client.env.yml
