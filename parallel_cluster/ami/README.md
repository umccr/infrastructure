# AWS EC2 Image builder recipes

Boostrap and provision your parallelcluster for interactive Cloud HPC Bioinformatics @UMCCR.

# What is this?

To introduce new software and build AMIs locally, [please read the official AWS documentation](https://docs.aws.amazon.com/imagebuilder/latest/userguide/image-builder-component-manager-local.html). A TL;DR would be:

```shell
$ wget https://awstoe-ap-southeast-2.s3.ap-southeast-2.amazonaws.com/latest/linux/amd64/awstoe -O /usr/local/bin/awstoe
$ chmod +x /usr/local/bin/awstoe
$ sudo su
# /usr/local/bin/awstoe run --documents base.yml,conda.yml,biocontainers.yml
```

If everything went well, it should conclude with a similar JSON message to the following:

```json
{
    "executionId": "52c3deda-d602-11ea-9cff-0a0f79d92462",
    "status": "success",
    "failedStepCount": 0,
    "executedStepCount": 3,
    "failureMessage": "",
    "logUrl": "/home/ec2-user/infrastructure/parallel_cluster/ami/TOE_2020-08-04_03-26-45_UTC-0_52c3deda-d602-11ea-9cff-0a0f79d92462"
}
```


# How do I include my software in the cluster's AMI?

For instance, if you needed a (newer?) version of samtools docker container:

![quay container search](../img/quayio_container.png)

Then:

    1. Add the docker tag to the `ami/biocontainers.yml` file.
    2. Rebuild the AMI as mentioned above.
    3. Tweak your pcluster config to point to that new AMI (via the `custom_ami` field).