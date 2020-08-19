\# TODO

\# Things to add to this Readme  
\# This also contains some slurm specific components.  
\# Should be a full readme inside parallel cluster
\# Put something on the how-to in umccr/wiki as well.
- How to submit WDL workflows to cromwell
  - curl, need to see if script works
- How to submit CWL workflows to cromwell.
  - curl?, need to see if script works, may need to pack script beforehand.
- How to view your workflow status?
  - What links can show me the status of my workflow
    - metadata
    - timing
    - also show how to map port 8000 to localhost
- How to debug your workflow?
  - Where are the logs for cromwell server?
    - currently in the home directory?
  - Where are the logs for a workflow?
    - in /cromwell/logs
    - in metadata
  - Where are the logs for a job?
    - in executions?
    - explain each of the submit, stdout, stderr
  - How can I tell if my jobs are running
    - check cromwell logs?
    - run `squeue`?
    - See metadata html?
    - how can I see where the outputs of a job are:
      - `scontrol show job <job-id>` 
  - What does 'ReqNodeNotAvail mean in slurm'  
    `The node may currently be in use, reserved for another job, in an advanced reservation, DOWN, DRAINED, or not responding.`
    - nodes take time to spin up etc.
- Where are my outputs?
  - in /fsx/cromwell/outputs or as specified in workflow.options.json
- How long does a node stay idle for?
  - 10 mins, see parallel-cluster, config
- How much does a node cost to run?
  - 0.30c for a m5.4xlarge in a spot instance
- How many workflows can I run simultaneously?
  - 10, see cromwell,slurm.conf
- How can I see what is going on in the compute nodes?
  - see which ip's are up, ssh in from ec2-user.
- What is cromshell and how can I use it?