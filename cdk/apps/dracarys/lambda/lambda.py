import json
import os
import boto3
import datetime
import base64
import logging
import subprocess

def handler(event, context):
    logging.info('request: {}'.format(json.dumps(event)))
    print('request: {}'.format(json.dumps(event)))
    msg_attrs = event['Records'][0]['messageAttributes']
    # TODO: Pass portal_run_id to dracarys and other attributes that are crucial for downstream linking
    try:
        file_prefix = msg_attrs['output_prefix']['stringValue']
        gds_input = msg_attrs['presign_url_json']['stringValue']
        target_bucket_name = msg_attrs['target_bucket_name']['stringValue']
    except Exception as e:
        logging.error("Exception:")
        logging.error(e)
        return { 'statusCode': 500 }

    # Retrieve ICA secret
    # https://aws.amazon.com/blogs/compute/securely-retrieving-secrets-with-aws-lambda/
    secrets_mgr = boto3.client('secretsmanager')
    ica_secret = secrets_mgr.get_secret_value(SecretId="IcaSecretsPortal")['SecretString']
    os.environ["ICA_ACCESS_TOKEN"] = ica_secret

    # TODO: Use lambda env vars or SSM instead
    DATA_ENV = "portal" # warehouse would be the other option
    # Do all work in /tmp (ill-advised operationally, though)
    CWD = "/tmp/dracarys"
    os.makedirs(CWD, exist_ok=True)

    # TODO: Add 3 more sample inputs
    output = run_command(["conda","run","-n","dracarys_env","/bin/bash","-c","dracarys.R tidy -i " + gds_input + " -o " + CWD + " -p " + file_prefix])

    s3 = boto3.resource('s3')
    target_prefix = DATA_ENV+"/creation_date="+datetime.datetime.now().strftime("%Y-%m-%d")+"/"
    target_fname = "dracarys_multiqc.tsv.gz"
    target_fname_path = find(target_fname, CWD)
    s3.meta.client.upload_file(target_fname_path, target_bucket_name, os.path.join(target_prefix, target_fname))
    returnmessage = ('Wrote ' + str(target_fname) + ' to s3://' + target_bucket_name )

    logging.info(returnmessage)
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/plain'
        },
        'body':  (returnmessage ) 
    }

def find(name, path):
    for root, _, files in os.walk(path):
        if name in files:
            return os.path.join(root, name)

def run_command(args):
    p = subprocess.Popen(args,
                          cwd = os.getcwd(),
                          stdin = subprocess.PIPE, 
                          stdout = subprocess.PIPE, 
                          stderr = subprocess.PIPE) 

    output, error = p.communicate() 
    logging.info("the commandline is {}".format(p.args))
    #getcommand(p)
    logging.info("the return code is " + str(p.returncode))
    if p.returncode == 0: 
        print('output :\n {0}'.format(output.decode("utf-8"))) 
        return output.decode("utf-8")
    else: 
        print('error due to return code ' + str(p.returncode ) + ':\n {0}'.format(error.decode("utf-8"))) 
        return error.decode("utf-8")

    return output

