import json
import os
import re
import boto3
import logging
import subprocess
from glob import glob

# Globals controlling early S3 path prefix
# TODO: Use lambda env vars or SSM instead
#DATA_ENV = "portal" # lakehouse would be the other option
LAKEHOUSE_VERSION = "v2"

def handler(event, context):
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
    secrets_mgr = boto3.client('secretsmanager')
    ica_secret = secrets_mgr.get_secret_value(SecretId="IcaSecretsPortal")['SecretString']
    os.environ["ICA_ACCESS_TOKEN"] = ica_secret

    # Do all work in /tmp (ill-advised operationally, though)
    CWD = "/tmp/dracarys"
    os.makedirs(CWD, exist_ok=True)

    gds_path_data = parse_gds_path_info(gds_input)
    if gds_path_data == None:
        raise ValueError("The GDS path {gds_input} is not recognised by this ingestor")

    # Deconstruct common gds_url components
    portal_run_id = gds_path_data['portal_run_id']
    portal_id_date_year = gds_path_data['portal_run_id_date'][0:4]
    portal_id_date_month = gds_path_data['portal_run_id_date'][4:6]
    sbj_id = gds_path_data['sbj_id']
    prj_id = gds_path_data['prj_id']

    # Run Dracarys
    cmd = ["conda","run","-n","dracarys_env","/bin/bash","-c","dracarys.R tidy -i " + gds_input + " -o " + CWD + " -p " + file_prefix, " -f both"]
    subprocess.check_output(cmd)

    # Collect output path
    target_s3_prefix = ""
    target_glob = file_prefix+"_*.tsv.gz" # TODO: Generalise for different file formats
    target_fname_paths = glob(os.path.join(CWD, target_glob))

    if "umccrise" in gds_input:
        target_s3_prefix = LAKEHOUSE_VERSION + \
            "/year=" + portal_id_date_year + \
            "/month=" + portal_id_date_month + \
            "/umccrise/multiqc" + \
            "/subject_id=" + sbj_id + \
            "/portal_run_id=" + portal_run_id + \
            "/project_id=" + prj_id + \
            "/tumor_lib=" + gds_path_data['tumor_lib'] + \
            "/normal_lib=" + gds_path_data['normal_lib']
    elif "wgs_alignment_qc" in gds_input:
        target_s3_prefix = LAKEHOUSE_VERSION + \
            "/year=" + portal_id_date_year + \
            "/month=" + portal_id_date_month + \
            "/wgs_alignment_qc/multiqc" + \
            "/subject_id=" + sbj_id + \
            "/portal_run_id=" + portal_run_id + \
            "/project_id=" + prj_id
    elif "tso_ctdna_tumor_only" in gds_input:
        target_s3_prefix = LAKEHOUSE_VERSION + \
            "/year=" + portal_id_date_year + \
            "/month=" + portal_id_date_month + \
            "/tso/tso_ctdna_tumor_only" + \
            "/subject_id=" + sbj_id + \
            "/portal_run_id=" + portal_run_id + \
            "/project_id=" + prj_id + \
            "/tumor_lib=" + gds_path_data['tumor_lib']

    for target_fname_path in target_fname_paths:
        target_on_s3 = os.path.join(target_s3_prefix, os.path.basename(target_fname_path))
        s3.meta.client.upload_file(target_fname_path, target_bucket_name, target_on_s3)
        logging.info("Wrote {target_on_s3}")

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/plain'
        }
    }

def parse_gds_path_info(gds_url: str):
    ''' A portal run id (20230311b504283e) is a string composed of
        a datetime 20230311 and a UUID/hash: b504283e 
    '''
    components = dict()

    # wgs_alignment_qc  multiqc regex
    #                                SBJID                     PORTAL_RUN_ID_DATE+HASH                             MULTIQC_DIR
    # gds://production/analysis_data/SBJXXXXX/wgs_alignment_qc/20230318aaf5c999/PRJXXXXXX_dragen_alignment_multiqc/PRJXXXXXX_dragen_alignment_multiqc_data
    gds_url_regex_multiqc = r"gds:\/\/production\/analysis_data\/(\w+)\/wgs_alignment_qc\/(\d{8})(\w+)\/\w+\/((\w+)_dragen_alignment_multiqc_data)"
    # umccrise          multiqc regex
    #                                SBJID             PORTAL_RUN_ID    TUMOR_LIB NORMAL_LIB  SBJID   PRJID     SBJID     PRJ_ID
    # gds://production/analysis_data/SBJXXXXX/umccrise/2022102142ed4512/LXXXXXXXX__LXXXXXXX/SBJXXXXX__MDXYYYYYY/SBJXXXXX__MDXYYYYYY-multiqc_report_data/multiqc_data.json
    gds_url_regex_multiqc_umccrise = r"gds:\/\/production\/analysis_data\/(\w+)\/umccrise\/(\d{8})(\w+)\/(\w+)__(\w+)\/(\w+)__(\w+)\/(\w+)__(\w+)-multiqc_report_data"
    # tso
    #
    # gds://production/analysis_data/SBJXXXXX/tso_ctdna_tumor_only/2021121773d2377a/L2100356/Results/PRJ210017_L2100356/
    gds_url_regex_tso_ctdna_tumor_only = r"gds:\/\/production\/analysis_data\/(\w+)\/tso_ctdna_tumor_only\/(\d{8})(\w+)\/(\w+)\/Results\/(\w+)_(\w+)"

    wgs_alignment_qc = re.search(gds_url_regex_multiqc, gds_url)
    umccrise_qc = re.search(gds_url_regex_multiqc_umccrise, gds_url)
    tso_ctdna_tumor = re.search(gds_url_regex_tso_ctdna_tumor_only, gds_url)

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
            raise ValueError("umccrise: SubjectID discrepancy detected in path")
        if umccrise_qc.group(7) != umccrise_qc.group(9):
            raise ValueError("umccrise: ProjectID discrepancy detected in path")

        components['prj_id'] = umccrise_qc.group(7)
    elif tso_ctdna_tumor:
        components['sbj_id'] = tso_ctdna_tumor.group(1)
        components['portal_run_id_date'] = tso_ctdna_tumor.group(2)
        components['portal_run_id_hash'] = tso_ctdna_tumor.group(3)
        components['portal_run_id'] = tso_ctdna_tumor.group(2) + tso_ctdna_tumor.group(3)
        components['tumor_lib'] = tso_ctdna_tumor.group(4)
        components['prj_id'] = tso_ctdna_tumor.group(5)

        if tso_ctdna_tumor.group(6) != tso_ctdna_tumor.group(4):
            raise ValueError("tso_ctdna_tumor: Library discrepancy detected in path")

    else:
        return None

    return components