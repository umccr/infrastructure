from __future__ import print_function

import sys
import os
import re
import argparse
import logging
from logging.handlers import RotatingFileHandler
import collections
from sample_sheet import SampleSheet
# Sample sheet library: https://github.com/clintval/sample-sheet

import warnings
warnings.simplefilter("ignore")

DEPLOY_ENV = os.getenv('DEPLOY_ENV')
SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

# Regex pattern for Sample ID/Name
topup_exp = '(?:_topup\d?)?'
sample_name_int = '(?:PRJ|CCR|MDX)\d{6}'
sample_name_ext = '.*'
sample_control = '(?:NTC|PTC)_'
sample_id_int = 'L\d{7}'
sample_id_ext = 'L' + sample_name_int
regex_sample_id_int = re.compile(sample_id_int + topup_exp)
regex_sample_id_ext = re.compile(sample_id_ext + topup_exp)
regex_sample_name = re.compile(sample_name_int + '_' + sample_name_ext + topup_exp)
regex_sample_ctl = re.compile(sample_control)


if DEPLOY_ENV == 'prod':
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
else:
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".dev.log")


def getLogger():
    new_logger = logging.getLogger(__name__)
    new_logger.setLevel(logging.DEBUG)

    # create a logging format
    formatter = logging.Formatter('%(asctime)s - %(module)s - %(name)s - %(levelname)s : %(lineno)d - %(message)s')

    # create a file handler
    file_handler = RotatingFileHandler(filename=LOG_FILE_NAME, maxBytes=100000000, backupCount=5)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)

    # create a console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.DEBUG)
    console_handler.setFormatter(formatter)

    # add the handlers to the logger
    new_logger.addHandler(file_handler)
    new_logger.addHandler(console_handler)

    return new_logger


def checkSampleSheetMetadata(samplesheet):
    logger.info("Checking SampleSheet metadata")
    if not samplesheet.Header.Assay:
        raise ValueError("Assay not defined in Header!")
    if not samplesheet.Header.get('Experiment Name'):
        raise ValueError("Experiment Name not defined in Header!")


def checkSampleSheetDataRecords(samplesheet):
    logger.info("Checking SampleSheet data records")
    for sample in samplesheet:
        logger.debug(f"Checking Sammple_ID/Sample_Name: {sample.Sample_ID}/{sample.Sample_Name}")
        if sample.Sample_ID == sample.Sample_Name:
            raise ValueError(f"Sample_ID '{sample.Sample_ID}' cannot be the same as the Sample_Name!")

        # check Sample ID against expected format
        if not (regex_sample_id_int.fullmatch(sample.Sample_ID) or regex_sample_id_ext.fullmatch(sample.Sample_ID)):
            raise ValueError(f"Sample_ID '{sample.Sample_ID}' did not match the expected pattern!")

        # check Sample Name against expected format
        if not (regex_sample_name.fullmatch(sample.Sample_Name) or regex_sample_ctl.match(sample.Sample_Name)):
            raise ValueError(f"Sample_Name '{sample.Sample_Name}' did not match the expected pattern!")

        sample.Sample_Name


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

        if sample.I7_Index_ID.startswith("SI-GA"):
            sorted_samples[("10X", index_length, index2_length)].append(sample)
            logger.debug(f"Adding sample {sample} to key (10X, {index_length}, {index2_length})")
        else:
            sorted_samples[("truseq", index_length, index2_length)].append(sample)
            logger.debug(f"Adding sample {sample} to key (truseq, {index_length}, {index2_length})")

    return sorted_samples


def writeSammpleSheets(sample_list, sheet_path, template_sheet):
    samplesheet_name = os.path.basename(sheet_path)
    samplesheet_dir = os.path.dirname(os.path.realpath(sheet_path))
    count = 0
    exit_status = "success"
    for key in sample_list:
        count += 1
        logger.debug(f"{len(sample_list[key])} samples with idx lengths {key[1]}/{key[2]} for {key[0]} dataset")

        new_sample_sheet = SampleSheet()
        new_sample_sheet.Header = template_sheet.Header
        new_sample_sheet.Reads = template_sheet.Reads
        new_sample_sheet.Settings = template_sheet.Settings
        for sample in sample_list[key]:
            new_sample_sheet.add_sample(sample)

        new_sample_sheet_file = os.path.join(samplesheet_dir, samplesheet_name + ".custom." + str(count) + "." + key[0])
        logger.info(f"Creating custom sample sheet: {new_sample_sheet_file}")
        try:
            with open(new_sample_sheet_file, "w") as ss_writer:
                new_sample_sheet.write(ss_writer)
        except Exception as error:
            logger.error(f"Exception writing new sample sheet: {error}")
            exit_status = "failure"

        logger.debug(f"Created custom sample sheet: {new_sample_sheet_file}")
    
    return exit_status


def main(samplesheet_file_path, check_only):
    logger.info(f"Checking SampleSheet {samplesheet_file_path}")
    original_sample_sheet = SampleSheet(samplesheet_file_path)

    # Run some consistency checks
    checkSampleSheetMetadata(original_sample_sheet)
    checkSampleSheetDataRecords(original_sample_sheet)

    if not check_only:
        # Sort samples based on technology (truseq/10X and/or index length)
        # Also replace N indexes with ""
        sorted_samples = getSortedSamples(original_sample_sheet)

        # Now that the samples have been sorted, we can write one or more custom sample sheets
        # (which may be the same as the original if no processing was necessary)
        logger.info(f"Writing {len(sorted_samples)} sample sheets.")
        writeSammpleSheets(sample_list=sorted_samples,
                           sheet_path=samplesheet_file_path,
                           template_sheet=original_sample_sheet)

    logger.info("All done.")


if __name__ == "__main__":
    logger = getLogger()
    logger.info(f"Invocation with parameters: {sys.argv[1:]}")

    if DEPLOY_ENV == "prod":
        logger.info("Running script in prod mode.")
    elif DEPLOY_ENV == "dev":
        logger.info("Running script in dev mode.")
    else:
        print("DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'.")
        exit(1)

    ################################################################################
    # argument parsing

    logger.debug("Setting up argument parser.")
    parser = argparse.ArgumentParser(description='Generate data for LIMS spreadsheet.')
    parser.add_argument('samplesheet',
                        help="The samplesheet to process.")
    parser.add_argument('--check-only', action='store_true',
                        help="Only run the checks, do not split the samplesheet.")

    logger.debug("Parsing arguments.")
    args = parser.parse_args()
    samplesheet_file_path = args.samplesheet
    check_only = True if args.check_only else False

    main(samplesheet_file_path=samplesheet_file_path, check_only=check_only)
