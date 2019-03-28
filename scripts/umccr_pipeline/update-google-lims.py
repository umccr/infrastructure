import os
import sys
import argparse
import re
import csv
from glob import glob
import pandas
from datetime import datetime
from sample_sheet import SampleSheet
import logging
from logging.handlers import RotatingFileHandler
import gspread  # maybe move to https://github.com/aiguofer/gspread-pandas
from oauth2client.service_account import ServiceAccountCredentials

import warnings
warnings.simplefilter("ignore")

################################################################################
# CONSTANTS

DEPLOY_ENV = os.getenv('DEPLOY_ENV')
if not DEPLOY_ENV:
    raise ValueError("DEPLOY_ENV needs to be set!")
SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

library_tracking_spreadsheet = "/storage/shared/dev/UMCCR_Library_Tracking_MetaData.xlsx"
# The column names should be kept in sync between the lab internal library tracking sheet and the Google LIMS
sample_id_column_name = 'SampleID'  # is the library ID
sample_name_column_name = 'SampleName'  # is the lab-external sample/library ID
assay_column_name = 'Type'  # the assay type: WGS, WTS, 10X, ...
phenotype_column_name = 'Phenotype'  # tomor, normal, negative-control, ...
quality_column_name = 'Quality'  # Good, Poor, Borderline
subject_column_name = 'SubjectID'  # ID for the subject/patient
source_column_name = 'Source'  # tissue, FFPE, ...
column_names = (subject_column_name, assay_column_name, phenotype_column_name, source_column_name, quality_column_name)

# column headers of the LIMS spreadsheet
sheet_column_headers = ("IlluminaID", "Run", "Timestamp", sample_id_column_name, sample_name_column_name,
                        "Project", subject_column_name, assay_column_name, phenotype_column_name, source_column_name, 
                        quality_column_name, "Secondary Analysis", "FASTQ", "Number FASTQs", "Results", "Trello",
                        "Notes", "ToDo")

# define argument defaults
if DEPLOY_ENV == 'prod':
    raw_data_base_dir = '/storage/shared/raw/Baymax'
    bcl2fastq_base_dir = '/storage/shared/bcl2fastq_output'
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
    spreadsheet_id = '1aaTvXrZSdA1ekiLEpW60OeNq2V7D_oEMBzTgC-uDJAM'  # 'Google LIMS' in Team Drive
else:
    raw_data_base_dir = '/storage/shared/dev/Baymax'
    bcl2fastq_base_dir = '/storage/shared/dev/bcl2fastq_output'
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".dev.log")
    spreadsheet_id = '1vX89Km1D8dm12aTl_552GMVPwOkEHo6sdf1zgI6Rq0g'  # 'Google LIMS dev' in Team Drive
runfolder_name_expected_length = 29
fastq_hpc_base_dir = '/data/cephfs/punim0010/data/Pipeline/prod/Fastq'
csv_outdir = '/tmp'
write_csv = False
creds_file = "/home/limsadmin/.google/google-lims-updater-b50921f70155.json"
skip_lims_update = False
failed_run = False

# pre-compile regex patterns
runfolder_pattern = re.compile('(\d{6})_.+_(\d{4})_.+')


################################################################################
# METHODS

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


def import_library_sheet(year):
    # TODO: error handling
    try:
        global library_tracking_spreadsheet_df
        library_tracking_spreadsheet_df = pandas.read_excel(library_tracking_spreadsheet, year)
        hit = library_tracking_spreadsheet_df.iloc[0]
        logger.debug(f"First record: {hit}")
        for column_name in column_names:
            logger.debug(f"Checking for column name {column_name}...")
            if column_name not in hit:
                logger.error(f"Could not find column {column_name}. The file is not structured as expected! Aborting.")
                exit(-1)
        logger.info(f"Loaded {len(library_tracking_spreadsheet_df.index)} records from library tracking sheet.")
    except Exception as e:
        logger.error(f"Failed to load library tracking data from: {library_tracking_spreadsheet}")


def get_meta_data(library_id, external_id):
    result = {}
    try:
        global library_tracking_spreadsheet_df
        hit = library_tracking_spreadsheet_df[library_tracking_spreadsheet_df[sample_id_column_name] == library_id]
        if len(hit) != 0:
            if hit[sample_name_column_name].values[0] != external_id:
                raise ValueError(f"Found external ID {hit[sample_name_column_name].values[0]} does not match " +
                                 f"provided one {external_id} for library {library_id}")
        else:
            # No hit with library ID, so we need to look for the external ID
            hit = library_tracking_spreadsheet_df[library_tracking_spreadsheet_df[sample_name_column_name] == external_id]
            if len(hit) == 0:
                raise ValueError(f"No entry found for external ID {external_id}!")

        for column_name in column_names:
            if not hit[column_name].isnull().values[0]:
                result[column_name] = hit[column_name].values[0]
            else:
                result[column_name] = '-'
    except Exception as e:
        logger.error(f"Could not find entry for sample {library_id}! Exception {e}")

    logger.info(f"Using values: {result} for sample {library_id}.")

    return result


def write_csv_file(output_file, column_headers, data_rows):
    with open(output_file, 'w', newline='') as csvfile:
        sheetwriter = csv.writer(csvfile, delimiter=',', quotechar='|', quoting=csv.QUOTE_MINIMAL)
        sheetwriter.writerow(column_headers)
        for row in data_rows:
            sheetwriter.writerow(row)


def write_to_google_lims(keyfile, spreadsheet_id, data_rows, failed_run):
    # follow example from: 
    # https://www.twilio.com/blog/2017/02/an-easy-way-to-read-and-write-to-a-google-spreadsheet-in-python.html
    scope = ['https://www.googleapis.com/auth/drive']
    creds = ServiceAccountCredentials.from_json_keyfile_name(keyfile, scope)
    client = gspread.authorize(creds)

    if failed_run:
        sheet = client.open_by_key(spreadsheet_id).worksheet('Failed Runs')
    else:
        sheet = client.open_by_key(spreadsheet_id).sheet1

    for row in data_rows:
        sheet.append_row(values=row, value_input_option='USER_ENTERED')


if __name__ == "__main__":
    logger = getLogger()
    logger.info(f"Invocation with parameters: {sys.argv[1:]}")

    ################################################################################
    # argument parsing

    logger.debug("Setting up argument parser.")
    parser = argparse.ArgumentParser(description='Generate data for LIMS spreadsheet.')
    parser.add_argument('runfolder',
                        help="The run/runfolder name.")
    parser.add_argument('--raw-data-base-dir',
                        help="The path to raw data (where to find the sample sheet used).",
                        default=raw_data_base_dir)
    parser.add_argument('--bcl2fastq-base-dir',
                        help="The base path (where to find the bcl2fastq output).",
                        default=bcl2fastq_base_dir)
    parser.add_argument('--fastq-hpc-base-dir',
                        help="The destination base path (depends on HPC env. ",
                        default=fastq_hpc_base_dir)
    parser.add_argument('--csv-outdir',
                        help="Where to write the CSV output file to. Default=/tmp).",
                        default=csv_outdir)
    parser.add_argument('--write-csv', action='store_true',
                        help="Use this flag to write a CSV file.")
    parser.add_argument('--spreadsheet-id',
                        help="The name of the Google LIMS spreadsheet.",
                        default=spreadsheet_id)
    parser.add_argument('--creds-file',
                        help="The Google credentials file to grant access to the spreadsheet.",
                        default=creds_file)
    parser.add_argument('--skip-lims-update', action='store_true',
                        help="Use this flag to skip the update of the Google LIMS.")
    parser.add_argument('--failed-run', action='store_true',
                        help="Use this flag to indicate a failed run (updates the Failed Runs sheet).")

    logger.debug("Parsing arguments.")
    args = parser.parse_args()
    if args.raw_data_base_dir:
        raw_data_base_dir = args.raw_data_base_dir
    if args.bcl2fastq_base_dir:
        bcl2fastq_base_dir = args.bcl2fastq_base_dir
    if args.fastq_hpc_base_dir:
        fastq_hpc_base_dir = args.fastq_hpc_base_dir
    if args.csv_outdir:
        csv_outdir = args.csv_outdir
    if args.write_csv:
        write_csv = True
    if args.spreadsheet_id:
        spreadsheet_id = args.spreadsheet_id
    if args.creds_file:
        creds_file = args.creds_file
    if args.skip_lims_update:
        skip_lims_update = True
    if args.failed_run:
        failed_run = True
    runfolder = args.runfolder

    # extract date and run number from runfolder name
    logger.debug("Parsing runfolder name.")
    if len(runfolder) != runfolder_name_expected_length:
        raise ValueError(f"Runfolder name {runfolder} did not match the expected \
                          length of {runfolder_name_expected_length} characters!")
    # TODO: perhaps include other runfolder name syntax checks
    try:
        run_date = re.search(runfolder_pattern, runfolder).group(1)
        run_no = re.search(runfolder_pattern, runfolder).group(2)
    except AttributeError:
        raise ValueError(f"Runfolder name {runfolder} did not match expected format: {runfolder_pattern}")

    run_timestamp = datetime.strptime(run_date, '%y%m%d').strftime('%Y-%m-%d')
    run_year = datetime.strptime(run_date, '%y%m%d').strftime('%Y')
    run_number = int(run_no)
    logger.info(f"Extracted run number/year/timestamp: {run_number}/{run_year}/{run_timestamp}")

    # load the library tracking sheet for the run year
    logger.debug("Loading library tracking data.")
    import_library_sheet(run_year)

    ################################################################################
    # Generate LIMS records from SampleSheet

    lims_data_rows = set()

    if failed_run:
        logger.info("Processing failed run. Using original sample sheet.")
        samplesheet_path_pattern = os.path.join(raw_data_base_dir, runfolder, 'SampleSheet.csv')
    else:
        logger.info("Processing successful run. Using generated sample sheet(s).")
        samplesheet_path_pattern = os.path.join(raw_data_base_dir, runfolder, 'SampleSheet.csv.custom.*')

    samplesheet_paths = glob(samplesheet_path_pattern)
    if len(samplesheet_paths) < 1:
        raise ValueError("No sample sheets found!")
    logger.info(f"Using {len(samplesheet_paths)} sample sheet(s).")

    for samplesheet in samplesheet_paths:
        logger.info(f"Processing samplesheet {samplesheet}")
        name, extension = os.path.splitext(samplesheet)
        samples = SampleSheet(samplesheet).samples
        logger.info(f"Found {len(samples)} samples.")
        for sample in samples:
            logger.debug(f"Looking up metadata for sammple ID; {sample.Sample_Name} and external ID: {sample.Sample_ID}")
            column_values = get_meta_data(sample.Sample_Name, sample.Sample_ID)

            if sample.Sample_Name == sample.Sample_ID:
                fastq_pattern = os.path.join(bcl2fastq_base_dir, runfolder, sample.Sample_Project,
                                             sample.Sample_Name + "*.fastq.gz")
                fastq_hpc_pattern = os.path.join(fastq_hpc_base_dir, runfolder, runfolder, sample.Sample_Project,
                                                 sample.Sample_Name + "*.fastq.gz")
            else:
                fastq_pattern = os.path.join(bcl2fastq_base_dir, runfolder, sample.Sample_Project,
                                             sample.Sample_ID, sample.Sample_Name + "*.fastq.gz")
                fastq_hpc_pattern = os.path.join(fastq_hpc_base_dir, runfolder, runfolder, sample.Sample_Project,
                                                 sample.Sample_ID, sample.Sample_Name + "*.fastq.gz")

            logger.debug('Looking for FASTQs: ' + fastq_pattern)
            logger.debug('Setting FASTQ dest: ' + fastq_hpc_pattern)
            fastq_file_paths = glob(fastq_pattern)
            if len(fastq_file_paths) < 1:
                logger.warn(f"Found no FASTQ files for sample {sample.Sample_ID}!")
            lims_data_rows.add((runfolder, run_number, run_timestamp, sample.Sample_Name, sample.Sample_ID,
                                sample.Sample_Project, column_values[subject_column_name],
                                column_values[assay_column_name], column_values[phenotype_column_name],
                                column_values[source_column_name], column_values[quality_column_name],
                                "-", fastq_hpc_pattern, len(fastq_file_paths), "-", "-", "-", ""))

    ################################################################################
    # write the data into a CSV file

    if write_csv:
        output_file = os.path.join(csv_outdir, runfolder + '-lims-sheet.csv')
        logger.info(f"Writing {len(lims_data_rows)} records to CSV file {output_file}")
        write_csv_file(output_file=output_file, column_headers=sheet_column_headers, data_rows=lims_data_rows)
    else:
        logger.info("Not writing CSV file.")

    if skip_lims_update:
        logger.warn("Skipping Google LIMS update!")
    else:
        logger.info(f"Writing {len(lims_data_rows)} records to Google LIMS {spreadsheet_id}")
        write_to_google_lims(keyfile=creds_file, spreadsheet_id=spreadsheet_id,
                             data_rows=lims_data_rows, failed_run=failed_run)

    logger.info("All done.")
