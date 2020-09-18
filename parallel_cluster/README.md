# UMCCR's AWS Parallel Cluster

[AWS Parallel cluster][aws_parallel_cluster] is a Cloud-HPC system designed to bring traditional HPC practices to the cloud.

UMCCR's intent is to onboard users to AWS, first on HPC and then steadily **transitioning to more cloud-native, efficient alternatives where suitable. This includes but is not limited to Illumina Access Platform (IAP).**

## Cluster Admin

### Setup

The [`conf/pcluster_client.env.yml` mentioned below][conda_conf] will setup `aws-parallelcluster` and other python dependencies on your python virtual environment. At UMCCR we typically use [Miniconda][miniconda], please set it up if you have not already before continuing.

You can follow the official [docs][install_doc] or [this][blog_1] blog post (section `Setting up your client environment`) to set up the client requirements for parallel cluster.

```shell
conda env create \
  --file conf/pcluster_client.env.yml \
  --name pcluster
```

This SSM shell function should be added to your `.bashrc` or equivalent:

```shell
ssm() {
    aws ssm start-session \
      --target "$1" \
      --document-name AWS-StartInteractiveCommand \
      --parameters command="sudo su - ec2-user"
}
```

So that logging into the instances becomes:

```bash
$ ssm i-XXXXXXXXXXXXX
```

> This assumes AmazonSSMManagedInstanceCore is set as an 
> additional policy in your parallel cluster config template i.e:
> additional_iam_policies = arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

### Running the cluster
> CLUSTER_NAME can only be alpha-numeric and must start with a letter

```shell
$ CLUSTER_TEMPLATE="tothill"  # or umccr_dev 
$ conda activate pcluster
$ ./bin/start_cluster.sh \
  <CLUSTER_NAME> 
  --cluster-template "${CLUSTER_TEMPLATE}"
Beginning cluster creation for cluster: my-test-cluster
Creating stack named: parallelcluster-my-test-cluster
Status: parallelcluster-my-test-cluster - CREATE_COMPLETE
MasterPublicIP: 3.104.49.154
ClusterUser: ec2-user
MasterPrivateIP: 172.31.23.110

Log in with 'ssm i-XXXXXXXX'   <---- Master instance ID

$ ssm i-XXXXXXXXXX

# Delete the cluster when finished
$ ./bin/stop_cluster.sh <CLUSTER_NAME>
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
`ssh local-ip-of-running-compute node`.  
Use sinfo to see the current list of running compute nodes.

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
  * `/efs` if using the efs configuration on `tothill` or `umccr_dev`
  * `/fsx` if using the fsx configuration on `umccr_dev_fsx`

#### Legacy HPC compatible commands 

The bootstrapping installs the `sinteractive` script also used on `Spartan` and it should work in the same way.  
>The Slurm native alternative can be used as well however this should be avoided due to a [AWS Parallel Cluster bug](https://github.com/aws/aws-parallelcluster/issues/1955)

```shell
$ sinteractive --time=10:00 --nodes=1 --cpus-per-task=1
```

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

The [cromshell_tookit][cromshell_repo] is also available under the `cromwell_tools` conda environment.

#### Logs and outputs
All outputs and logs should be under `/efs/cromwell` (or `/fsx/cromwell`)
These need to be part of the shared filesystem.
Jobs are run through a slurm/docker configuration.

### Running through toil

Please look through the [toil README](toil/README.md) or checkout the [examples page](working_examples/toil/gridss-purple-linx-cwl.md)
for guidance.

### Installing new software on the cluster

Refer to [the custom AMI README.md](ami/README.md) to include your own (bioinformatics) software.

Both conda and docker are is also installed on our *standard* AMI 

> Not currently standard

### File System

> Currently under development and discussion.  
> Subject to change

The cluster uses EFS to provide a **filesystem that is available to all nodes**. 
This means that all compute nodes have access to the same FS and don't necessarily have to stage their own data 
(if it was already put in place). 
However, that also means the data put into EFS remains available (and chargeable) as long as the cluster remains. 
So data will have to be cleaned up manually after it fulfilled it's purpose.

One can also specify to use an `fsx lustre` filesystem. This will be faster but more expensive for most use cases.

Both EFS and FSX systems are purged on the deletion of the stack. Please ensure you have copied your data 
you wish to save back to S3

**Not yet implemented**
> /mnt/refdata    (mapping s3://umccr-refdata-dev for all genomics reference data)
> /mnt/data       (mapping to s3://umccr-temp-dev for input datasets)
> Those mount points are subject to change, this is a work in progress that requires human consensus.

### Limitations

The current cluster and scheduler (SLURM) run with minimal configuration, so there will be some limitations. Known points include:

- `--mem` option is not natively suppported:
    * Whilst it can be used, there is no slurm controller enforcing memory. 
    * Since you are probably the only one using the cluster, 
      please do not exploit this or forever suffer the consequences.

## Some use cases

The following worklows are working examples you can run through to see AWS Parallel Cluster in action.

### Toil

[Gridss Purple Linx CWL](working_examples/toil/gridss-purple-linx-cwl.md)

### Cromwell

[Haplotype Caller WDL](working_examples/cromwell/haplotype-caller.md)

### bcbio
> Not this is not currently a working example due to a novel failure

[bcbio variant calling example](working_examples/bcbio/bcbio-nextgen.md)

## Troubleshooting

### Failed to build cluster
> The following resource(s) failed to create: [MasterServerWaitCondition, ComputeFleet].

This has been seen with two main causes.
1. The AMI is not compatible with parallel cluster see [this github issue][ami_parallel_cluster_issue]
2. The pre_install script has failed to run successfully.
3. The post_install script has failed to run successfully.

If you have used the `--no-rollback` flag you should be able to log into the master node via ssm.
From here, you should check the file `/var/log/cfn-init.log` to see where your start up failed. 

### It's taking a long time for my job to start
Head to the ec2 console and check to see if a new compute node is running.
Ensure that you can see the logs of the compute node by clicking on the console,
if not, the compute node has probably not launched completely yet, give it another few minutes.

If however you can see the logs, and everything seems okay it may be worth doing the following.

1. Run the `sacct` command to see the status of your job. 
2. Check that the `compute` node is not in drain mode, `scontrol show partition=compute`.
3. If you have used `srun --pty bash` to login to the node, use `sinteractive` instead due to a known bug.

### Cannot log into AWS SSO whilst in pcluster env
This is caused by a decision from aws not to support v2 on pip.  
When you run the pcluster installation command it installs aws v1 onto your conda env.  
You'll need to open up a new shell (that is not in your pcluster conda env) to login via sso.  
Many people arent happy about this. You can rant to them [here][aws_doesnt_support_pip_bug]

### The vpc ID 'vpc-XXXX' does not exist
This can be caused by trying to access a network configuration outside your permissions.
Ensure you're setting `--cluster-template` correctly and pointing to the right config-file with `--config`

[install_doc]: https://docs.aws.amazon.com/parallelcluster/latest/ug/install.html
[blog_1]: https://aws.amazon.com/blogs/machine-learning/building-an-interactive-and-scalable-ml-research-environment-using-aws-parallelcluster/
[aws_parallel_cluster]: https://aws.amazon.com/hpc/parallelcluster/
[miniconda]: https://docs.conda.io/en/latest/miniconda.html
[conda_conf]: https://github.com/umccr/infrastructure/blob/master/parallel_cluster/conf/pcluster_client.env.yml
[slurm_mem_solution]: https://github.com/aws/aws-parallelcluster/issues/1517#issuecomment-561775124
[accounting_blog]: https://aws.amazon.com/blogs/compute/enabling-job-accounting-for-hpc-with-aws-parallelcluster-and-amazon-rds/
[sbatch_guide]: https://slurm.schedmd.com/sbatch.html
[sbcast_guide]: https://slurm.schedmd.com/sbcast.html
[cromshell_repo]: https://github.com/broadinstitute/cromshell
[aws_doesnt_support_pip_bug]: https://github.com/aws/aws-cli/issues/4947
