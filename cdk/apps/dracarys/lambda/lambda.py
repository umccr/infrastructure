import json
import os
import re
import boto3
import datetime
import base64
import logging
import subprocess

def handler(event, context):
    #now = datetime.datetime.now().strftime("%Y-%m-%d")
    s3 = boto3.resource('s3')

    logging.info('request: {}'.format(json.dumps(event)))
    print('request: {}'.format(json.dumps(event)))
    msg_attrs = event['Records'][0]['messageAttributes']
    # TODO: Pass portal_run_id to dracarys and other attributes that are crucial for downstream linking
    try:
        file_prefix = msg_attrs['output_prefix']['stringValue']
        gds_input = msg_attrs['gds_input']['stringValue']
        target_bucket_name = msg_attrs['target_bucket_name']['stringValue']
        portal_run_id = msg_attrs['portal_run_id']['stringValue']
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

    gds_path_data = parse_gds_path_info(gds_input)
    assert(gds_path_data != None)

    # Forced to parse portal_run_id from GDS URL for now... 
    #output = run_command(["conda","run","-n","dracarys_env","/bin/bash","-c","dracarys.R tidy -i " + gds_input + " -o " + CWD + " -p " + file_prefix, "--portal-run-id", portal_run_id])
    output = run_command(["conda","run","-n","dracarys_env","/bin/bash","-c","dracarys.R tidy -i " + gds_input + " -o " + CWD + " -p " + file_prefix, " -f both"])

    # Write in both TSV and Parquet formats
    target_fname = "multiqc_data.parquet"
    target_fname_path = find(target_fname, CWD)
    target_prefix = DATA_ENV+"/creation_date="+ gds_path_data['portal_run_id_date'] + "/subject_id="+ gds_path_data['sbj_id'] +" /format=parquet"
    s3.meta.client.upload_file(target_fname_path, target_bucket_name, os.path.join(target_prefix, target_fname))

    target_fname = "multiqc_data.tsv.gz"
    target_fname_path = find(target_fname, CWD)
    target_prefix = DATA_ENV+"/creation_date="+ gds_path_data['portal_run_id_date'] + "/subject_id="+ gds_path_data['sbj_id'] +" /format=tsv"
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

def parse_gds_path_info(gds_url: str) -> dict | None:
    ''' A portal run id (20230311b504283e) is a string composed of
        a datetime 20230311 and a UUID/hash: b504283e 
    '''
    #                                                      SBJID   PORTAL_RUN_ID_DATE+HASH  MULTIQC_DIR
    gds_url_regex = r'/gds:\/\/production\/analysis_data\/(\w+)\/\w+\/(\d{8})(\w+)\/\w+\/(\w+)\//'
    match = re.search(gds_url_regex, gds_url)
    components = dict()

    if match:
        components['sbj_id'] = match.group(1)
        components['portal_run_id_date'] = match.group(2)
        components['portal_run_id_hash'] = match.group(3)
        components['multiqc_dir'] = match.group(4)

        return components
    else:
        return None

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
    logging.info("the return code is " + str(p.returncode))
    if p.returncode == 0: 
        print('output :\n {0}'.format(output.decode("utf-8"))) 
        return output.decode("utf-8")
    else: 
        print('error due to return code ' + str(p.returncode ) + ':\n {0}'.format(error.decode("utf-8"))) 
        return error.decode("utf-8")

    return output

