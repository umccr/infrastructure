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
> Ensure that AmazonSSMManagedInstanceCore is set as an additional policy in your config  
> additional_iam_policies = arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

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
> CLUSTER_NAME can only be alpha-numeric and must start with a letter

```shell
$ CLUSTER_TEMPLATE="tothill"  # or umccr_dev 
$ ./bin/start_cluster.sh \
  <CLUSTER_NAME> 
  --cluster-template "${CLUSTER_TEMPLATE}"
Beginning cluster creation for cluster: my-test-cluster
Creating stack named: parallelcluster-my-test-cluster
Status: parallelcluster-my-test-cluster - CREATE_COMPLETE
MasterPublicIP: 3.104.49.154
ClusterUser: ec2-user
MasterPrivateIP: 172.31.23.110

< Currently not implemented, instance ID can be seen in the console >
i-XXXXXXXXX   <---- Master instance ID

$ ssm i-XXXXXXXXXX

# Delete the cluster when finished
$ ./bin/stop-cluster.sh <CLUSTER_NAME>
```

## Cluster Use

### Logging into the master node
```shell
# Login to the master node
ssm <instance ID>

# Run Slurm commands as usual
sinfo ...
squeue ...
srun ...
sbatch ...
```

### Logging into a computer node
You can also log into a computer node from the master node,
from the `ec2-user`, this is handy for debugging purposes:   
`ssh local-ip-of-running-compute node`

### Using slurm
See [sbatch guide][sbatch_guide] for more information
Example batch script file
```shell
#!/bin/bash
#SBATCH --output %J.out
#SBATCH --error %J.err
#SBATCH --time=00:05:00

echo 'Foo'
docker run --rm hello-world
```

If you are submitting a job that requires a file that is exclusively on one node,
you may consider using [sbcast][sbcast_guide] parameter to ensure that the file is
copied to the worker node. Alternatively place the file inside a location that is shared
by both the submission and execution node. 

#### Legacy HPC compatible commands 

The bootstrapping installs the `sinteractive` script also used on `Spartan` and it should work in the same way. The Slurm native alternative can be used as well: 

```shell
$ sinteractive --time=10:00 --nodes=1 --cpus-per-task=1
$ srun --time=10:00 --nodes=1 --cpus-per-task=1 --pty -u "/bin/bash" -i -l
```

Eventually, when users are ready to make the transition, this will be migrated to AWS Batch or more modern, efficient and integrated compute scheduling systems.

### Running through cromwell
The cromwell server runs under the ec2-user on port 8000.
You can submit to the server via curl like so:

```bash
curl -X  POST "http://localhost:8000/api/workflows/v1"  \
    -H "accept: application/json" \
    -F "workflowSource=@rnaseq_pipeline.wdl" \
    -F "workflowInputs=@rnaseq_pipeline.json" \
    -F "workflowDependencies=@tasks.zip"
    -F "workflowOptions=/opt/cromwell/configs/options.json"
```

#### Logs and outputs
All outputs and logs should be under /fsx/cromwell.
These need to be part of the shared filesystem.
Jobs are run through a slurm/docker configuration.

### Installing new software on the cluster

Refer to [the custom AMI README.md](ami/README.md) to include your own (bioinformatics) software.

Both conda and docker are is also installed on our *standard* AMI 

> Not currently standard

### File System

The cluster uses EFS to provide a **filesystem that is available to all nodes**. This means that all compute nodes have access to the same FS and don't necessarily have to stage their own data (if it was already put in place). However, that also means the data put into EFS remains avaiable (and chargeable) as long as the cluster remains. So data will have to be cleaned up manually after it fulfilled it's purpose.

This cluster also **uses AWS FSx lustre to access UMCCR "data lakes" or S3 buckets** where all the research data resides. Those S3 buckets are made available through:

```
/mnt/refdata    (mapping s3://umccr-refdata-dev for all genomics reference data)
/mnt/data       (mapping to s3://umccr-temp-dev for input datasets)
```

Those mount points are subject to change, this is a work in progress that requires human consensus.

> fsx configurations are also possible

### Limitations

The current cluster and scheduler (SLURM) run with minimal configuration, so there will be some limitations. Known points include:

- Slurm's accounting (`sacct`) is not supported, as it requires an accounting data store to be set up.
    > This has been set up in the [slurm_boostrap_file](bootstrap/bootstrap-slurm-cromwell.sh)  
    > You will also need to create a security group for the RDS  
    > And add this security group to your config under 'additional_sg'
    * Explained in the [blog post here][accounting_blog]
- `--mem` option may cause a job to fail with `Requested node configuration is not available`
    > This has been fixed in the [slurm_boostrap_file](bootstrap/bootstrap-slurm-cromwell.sh)
    * See [workaround suggested here][slurm_mem_solution]
    
## Troubleshooting

### Failed to build cluster
> The following resource(s) failed to create: [MasterServerWaitCondition, ComputeFleet].

This has been seen with two main causes.
1. The AMI is not compatible with parallel cluster see [this github issue][ami_parallel_cluster_issue]
2. The post_install script has failed to run successfully.



[install_doc]: https://docs.aws.amazon.com/parallelcluster/latest/ug/install.html
[blog_1]: https://aws.amazon.com/blogs/machine-learning/building-an-interactive-and-scalable-ml-research-environment-using-aws-parallelcluster/
[aws_parallel_cluster]: https://aws.amazon.com/hpc/parallelcluster/
[miniconda]: https://docs.conda.io/en/latest/miniconda.html
[conda_conf]: https://github.com/umccr/infrastructure/blob/master/parallel_cluster/conf/pcluster_client.env.yml
[slurm_mem_solution]: https://github.com/aws/aws-parallelcluster/issues/1517#issuecomment-561775124
[accounting_blog]: https://aws.amazon.com/blogs/compute/enabling-job-accounting-for-hpc-with-aws-parallelcluster-and-amazon-rds/
[sbatch_guide]: https://slurm.schedmd.com/sbatch.html
[sbcast_guide]: https://slurm.schedmd.com/sbcast.html