import json
import os
import boto3 #todo all to pip
import datetime
import base64
import logging
import subprocess

def handler(event, context):
    logging.info('request: {}'.format(json.dumps(event)))
    print('request: {}'.format(json.dumps(event)))
    body = json.loads(event['Records'][0]['messageAttributes'])
    try:
        output_prefix=body['output_prefix']['stringValue']
        gds_input=body['presign_url_json']['stringValue']
        target_bucket_name=body['target_bucket_name']['stringValue']
    except Exception as e:
        logging.error("Exception:")
        logging.error(e)
        return { 'statusCode': 500 }

    # Retrieve ICA secret
    # https://aws.amazon.com/blogs/compute/securely-retrieving-secrets-with-aws-lambda/
    secrets_mgr = boto3.client('secretsmanager')
    ica_secret = secrets_mgr.get_secret_value("IcaV2SecretsPortal")
    os.environ["ICA_ACCESS_TOKEN"] = ica_secret

    # Do all work in /tmp
    WD = "/tmp"
    #output = run_command(["curl","-o",WD + "/" + output_prefix+".json", gds_input]) # Not needed since newer versions of Dracarys handle GDS presign generation
    output = run_command(["conda","run","-n","dracarys_env","/bin/bash","-c","dracarys.R tidy -i " + gds_input + " -o " + WD + "/ -p " + output_prefix])
    #output = run_command(["cat",WD+"/"+output_prefix+".tsv"])

    region = 'ap-southeast-2'
    s3 = boto3.resource('s3',region_name=region)
    target_filename = output_prefix+"."+datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")+".tsv"
    s3.meta.client.upload_file(WD+"/"+output_prefix+".tsv", target_bucket_name, target_filename)
    returnmessage = ('Wrote ' + str(target_filename) + ' to s3://' + target_bucket_name ) 
    logging.info(returnmessage)
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/plain'
        },
        'body':  (returnmessage ) 
    }

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

