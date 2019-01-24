from __future__ import print_function

import sys
import os
import json
import socket
import datetime
import collections
import boto3
from sample_sheet import SampleSheet
# Sample sheet library: https://github.com/clintval/sample-sheet

import warnings
warnings.simplefilter("ignore")

DEPLOY_ENV = os.getenv('DEPLOY_ENV')
SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
if DEPLOY_ENV == 'prod':
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
else:
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".dev.log")
UDP_IP = "127.0.0.1"
UDP_PORT = 9999
LOG_FILE = open(LOG_FILE_NAME, "a+")
SOCK = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # UDP


def write_log(msg):
    now = datetime.datetime.now()
    msg = f"{now} {SCRIPT}: {msg}"

    if DEPLOY_ENV == 'prod':
        SOCK.sendto(bytes(msg+"\n", "utf-8"), (UDP_IP, UDP_PORT))
    else:
        print(msg)
    print(msg, file=LOG_FILE)


def aws_callback(task_token, status, runfolder_name, error_message=None):
    """ Call back to the AWS Step Function State Machine (workflow)
    """
    states_client = boto3.client('stepfunctions')

    payload = {
        "runfolder": runfolder_name,
        "status": status
    }
    if error_message:
        payload['error_message'] = error_message

    response = states_client.send_task_success(
        taskToken=task_token,
        output=json.dumps(payload)
    )

    return response


def getSortedSamples(samplesheet):
    sorted_samples = collections.defaultdict(list)
    for sample in samplesheet:
        # replace N index with ""
        sample.index = sample.index.replace("N", "")
        index_length = len(sample.index)

        if sample.index2:
            sample.index2 = sample.index2.replace("N", "")
            index2_length = len(sample.index2)
            # make sure to remove the index ID if there is no index sequence
            if index2_length is 0:
                sample.I5_Index_ID = ""
        else:
            index2_length = 0

        if sample.Sample_ID.startswith("SI-GA"):
            sample.Sample_ID = sample.Sample_Name
            sorted_samples[("10X", index_length, index2_length)].append(sample)
            write_log(f"DEBUG: Adding sample {sample} to key (10X, {index_length}, {index2_length})")
        else:
            sorted_samples[("truseq", index_length, index2_length)].append(sample)
            write_log(f"DEBUG: Adding sample {sample} to key (truseq, {index_length}, {index2_length})")

    return sorted_samples


def writeSammpleSheets(sample_list, sheet_path, template_sheet):
    samplesheet_name = os.path.basename(sheet_path)
    samplesheet_dir = os.path.dirname(os.path.realpath(sheet_path))
    count = 0
    exit_status = "success"
    for key in sample_list:
        count += 1
        write_log(f"DEBUG: {len(sample_list[key])} samples with idx lengths {key[1]}/{key[2]} for {key[0]} dataset")

        new_sample_sheet = SampleSheet()
        new_sample_sheet.Header = template_sheet.Header
        new_sample_sheet.Reads = template_sheet.Reads
        new_sample_sheet.Settings = template_sheet.Settings
        for sample in sample_list[key]:
            new_sample_sheet.add_sample(sample)

        new_sample_sheet_file = os.path.join(samplesheet_dir, samplesheet_name + ".custom." + str(count) + "." + key[0])
        write_log(f"INFO: Creating custom sample sheet: {new_sample_sheet_file}")
        try:
            with open(new_sample_sheet_file, "w") as ss_writer:
                new_sample_sheet.write(ss_writer)
        except Exception as error:
            write_log("ERROR: Exception writing new sample sheet.")
            write_log(f"ERROR: {error}")
            exit_status = "failure"

        write_log(f"DEBUG: Created custom sample sheet: {new_sample_sheet_file}")
    
    return exit_status


def main(samplesheet_file_path, runfolder_name, task_token):
    write_log(f"Invocation with: samplesheet_path:{samplesheet_file_path} "
              f"runfolder_name:{runfolder_name} "
              f"task_token:{task_token[:10]}...")

    write_log(f"INFO: Checking SampleSheet {samplesheet_file_path}")
    original_sample_sheet = SampleSheet(samplesheet_file_path)

    # Sort samples based on technology (truseq/10X and/or index length)
    # Also replace N indexes with ""
    sorted_samples = getSortedSamples(original_sample_sheet)

    # Now that the samples have been sorted, we can write one or more custom sample sheets
    # (which may be the same as the original if no processing was necessary)
    write_log(f"INFO: Writing {len(sorted_samples)} sample sheets.")
    write_status = writeSammpleSheets(sample_list=sorted_samples,
                                      sheet_path=samplesheet_file_path,
                                      template_sheet=original_sample_sheet)

    # Finally call back the AWS pipeline to it can continue
    write_log("INFO: Callback to AWS...")
    callback_response = aws_callback(task_token=task_token,
                                     status=write_status,
                                     runfolder_name=runfolder_name)
    write_log(f"DEBUG: AWS callback response: {callback_response}")

    write_log("INFO: All done.")


if __name__ == "__main__":
    if DEPLOY_ENV == "prod":
        write_log("Running script in prod mode.")
    elif DEPLOY_ENV == "dev":
        write_log("Running script in dev mode.")
    else:
        print("DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'.")
        exit(1)

    # TODO: validate input parameters
    samplesheet_file_path = sys.argv[1]
    runfolder_name = sys.argv[2]
    task_token = sys.argv[3]

    main(samplesheet_file_path=samplesheet_file_path,
         runfolder_name=runfolder_name,
         task_token=task_token)

    LOG_FILE.close()
    SOCK.close()
