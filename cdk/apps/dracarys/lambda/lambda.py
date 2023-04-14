import json
import os
import re
import boto3
import datetime
import base64
import logging
import subprocess

# Globals controlling early S3 path prefix
# TODO: Use lambda env vars or SSM instead
#DATA_ENV = "portal" # lakehouse would be the other option
LAKEHOUSE_VERSION = "v2"

def handler(event, context):
    #now = datetime.datetime.now().strftime("%Y-%m-%d")
    s3 = boto3.resource('s3')

    logging.info('request: {}'.format(json.dumps(event)))
    print('request: {}'.format(json.dumps(event)))
    msg_attrs = event['Records'][0]['messageAttributes']
    try:
        file_prefix = msg_attrs['output_prefix']['stringValue']
        gds_input = msg_attrs['gds_input']['stringValue']
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

    # Do all work in /tmp (ill-advised operationally, though)
    CWD = "/tmp/dracarys"
    os.makedirs(CWD, exist_ok=True)

    gds_path_data = parse_gds_path_info(gds_input)
    assert gds_path_data is not None

    portal_id_date = gds_path_data['portal_run_id_date']

    # Forced to parse portal_run_id from GDS URL for now... 
    #output = run_command(["conda","run","-n","dracarys_env","/bin/bash","-c","dracarys.R tidy -i " + gds_input + " -o " + CWD + " -p " + file_prefix, "--portal-run-id", portal_run_id])
    output = run_command(["conda","run","-n","dracarys_env","/bin/bash","-c","dracarys.R tidy -i " + gds_input + " -o " + CWD + " -p " + file_prefix, " -f both"])

    target_prefix = ""
    target_fname = file_prefix+"_multiqc.tsv.gz"
    target_fname_path = find(target_fname, CWD)

    if "umccrise" in gds_input:
        target_prefix = LAKEHOUSE_VERSION +"/"+ \
            "/year=" + portal_id_date[0:3] + \
            "/month=" + portal_id_date[4:5] + \
            "/umccrise/multiqc" + \
            "/subject_id=" + gds_path_data['sbj_id'] + \
            "/portal_run_id=" + gds_path_data['portal_run_id'] + \
            "/project_id=" + gds_path_data['prj_id'] + \
            "/tumor_lib=" + gds_path_data['tumor_lib'] + \
            "/normal_lib=" + gds_path_data['normal_lib'] + \
            "/format=tsv/"

    elif "wgs_alignment_qc" in gds_input:
        target_prefix = LAKEHOUSE_VERSION +"/"+ \
            "/year=" + portal_id_date[0:3] + \
            "/month=" + portal_id_date[4:5] + \
            "/wgs_alignment_qc/multiqc" + \
            "/subject_id=" + gds_path_data['sbj_id'] + \
            "/portal_run_id=" + gds_path_data['portal_run_id'] + \
            "/project_id=" + gds_path_data['prj_id'] + \
            "/format=tsv/"

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

def parse_gds_path_info(gds_url: str):
    ''' A portal run id (20230311b504283e) is a string composed of
        a datetime 20230311 and a UUID/hash: b504283e 
    '''
    components = dict()

    # wgs_alignment_qc  multiqc regex
    #                                SBJID                     PORTAL_RUN_ID_DATE+HASH                             MULTIQC_DIR
    # gds://production/analysis_data/SBJXXXXX/wgs_alignment_qc/20230318aaf5c999/PRJXXXXXX_dragen_alignment_multiqc/PRJXXXXXX_dragen_alignment_multiqc_data
    gds_url_regex_multiqc = r"gds:\/\/production\/analysis_data\/(\w+)\/\wgs_alignment\/(\d{8})(\w+)\/\w+\/((\w+)_dragen_alignment_multiqc_data)"
    # umccrise          multiqc regex
    #                                SBJID             PORTAL_RUN_ID    TUMOR_LIB NORMAL_LIB  SBJID   PRJID     SBJID     PRJ_ID
    # gds://production/analysis_data/SBJXXXXX/umccrise/2022102142ed4512/LXXXXXXXX__LXXXXXXX/SBJXXXXX__MDXYYYYYY/SBJXXXXX__MDXYYYYYY-multiqc_report_data/multiqc_data.json
    gds_url_regex_multiqc_umccrise = r"gds:\/\/production\/analysis_data\/(\w+)\/umccrise\/(\d{8})(\w+)\/(\w+)__(\w+)\/(\w+)__(\w+)\/(\w+)__(\w+)-multiqc_report_data"

    wgs_alignment_qc = re.search(gds_url_regex_multiqc, gds_url)
    umccrise_qc = re.search(gds_url_regex_multiqc_umccrise, gds_url)

    # TODO: Refactor later, following worse is better mode
    if wgs_alignment_qc:
        components['sbj_id'] = wgs_alignment_qc.group(1)
        components['portal_run_id_date'] = wgs_alignment_qc.group(2)
        components['portal_run_id_hash'] = wgs_alignment_qc.group(3)
        components['portal_run_id'] = wgs_alignment_qc.group(2) + wgs_alignment_qc.group(3)

        components['multiqc_dir'] = wgs_alignment_qc.group(4)
        components['prj_id'] = wgs_alignment_qc.group(5)
    elif umccrise_qc:
        components['sbj_id'] = umccrise_qc.group(1)
        components['portal_run_id_date'] = umccrise_qc.group(2)
        components['portal_run_id_hash'] = umccrise_qc.group(3)
        components['portal_run_id'] = umccrise_qc.group(2) + umccrise_qc.group(3)

        components['tumor_lib'] = umccrise_qc.group(4)
        components['normal_lib'] = umccrise_qc.group(5)

        if umccrise_qc.group(6) != umccrise_qc.group(8):
            raise ValueError("SubjectID discrepancy detected")
        if umccrise_qc.group(7) != umccrise_qc.group(9):
            raise ValueError("ProjectID discrepancy detected")

        components['prj_id'] = umccrise_qc.group(7)
    else:
        return None

    return components

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

