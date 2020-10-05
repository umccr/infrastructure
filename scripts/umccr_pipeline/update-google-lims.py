#!/usr/bin/env python3
import os
import re
import sys
import argparse
import collections
from datetime import datetime
from pathlib import Path
import pandas as pd
import csv
from umccr_utils.google_lims import get_library_sheet_from_google, write_to_google_lims, write_to_local_lims
from umccr_utils.samplesheet import get_years_from_samplesheet, SampleSheet
from umccr_utils.logger import set_logger, set_basic_logger
from umccr_utils.globals import LIMS_COLUMNS, LAB_SPREAD_SHEET_ID, LIMS_SPREAD_SHEET_ID, \
    NOVASTOR_CSV_DIR, NOVASTOR_RAW_BCL_DIR, NOVASTOR_FASTQ_OUTPUT_DIR, \
    FASTQ_S3_BUCKET, RUN_REGEX_OBJS, INSTRUMENT_NAMES, METADATA_COLUMN_NAMES, NOVASTOR_CRED_PATHS, \
    OVERRIDE_CYCLES_OBJS


import warnings
warnings.simplefilter("ignore")


def get_args():
    """
    Get arguments from the commandline
    :return:
    """
    logger.debug("Setting up argument parser.")
    parser = argparse.ArgumentParser(description='Generate data for LIMS spreadsheet.')
    parser.add_argument('runfolder',
                        help="The run/runfolder name.")
    parser.add_argument("--deploy-env",
                        required=False,
                        choices=["dev", "prod"],
                        help="Used to determine lims sheet ID and metadata ID paths."
                             "If not specified, DEPLOY_ENV env var must be specified")
    parser.add_argument('--raw-data-base-dir',
                        help="The path to raw data (where to find the raw data folders, i.e. the runfolder)."
                             "Use the --deploy")
    parser.add_argument('--bcl2fastq-base-dir',
                        help="The base path (where to find the bcl2fastq output).")
    parser.add_argument('--fastq-hpc-base-dir',
                        help="The destination base path (depends on HPC env. ",)
    parser.add_argument('--csv-outdir',
                        help="Where to write the CSV output file to. Default=/tmp).",
                        default=NOVASTOR_CSV_DIR)
    parser.add_argument('--write-csv', action='store_true',
                        help="Use this flag to write a CSV file.")

    write_parser = parser.add_mutually_exclusive_group()

    write_parser.add_argument('--creds-file',
                              required=False,
                              help="The Google credentials file to grant access to the spreadsheet."
                                   "Must be specified if --skip-lims-update is not specified",
                              default=NOVASTOR_CRED_PATHS["google_write_token"])
    write_parser.add_argument("--update-local-lims",
                              required=False,
                              help="Update a local LIMS file instead. Useful for debugging purposes."
                                   "File must exist with the right sheet names and headers."
                                   "Not compatibile with --skip-lims-update or --creds-file parameters")
    write_parser.add_argument('--skip-lims-update', action='store_true',
                              default=False,
                              help="Use this flag to skip the update of the Google LIMS.")
    parser.add_argument('--failed-run', action='store_true',
                        default=False,
                        help="Use this flag to indicate a failed run (updates the Failed Runs sheet).")

    logger.debug("Parsing arguments.")
    return parser.parse_args()


def set_args(args):
    """
    Ensure args are right
    :param args:
    :return:
    """

    # Now we know the deploy-env, we can set the file handle
    global logger

    # Check runfolder regex
    # Runfolder is a subdirectory of --raw-data-base-dir
    run_folder_arg = getattr(args, "runfolder", None)

    # Check run folder matches regex
    if RUN_REGEX_OBJS["run_fullmatch"].fullmatch(run_folder_arg) is None:
        logger.error("Could not match \"{}\" with run regex. Exiting".format(run_folder_arg))
        sys.exit(1)

    # Get run Attributes
    run_date, machine_id, run_number, slot_id, flowcell_id = get_run_attributes_from_run_name(run_folder_arg)

    # Set each of these as arguments
    setattr(args, "run_date", run_date)
    setattr(args, "machine_id", machine_id)
    setattr(args, "run_number", run_number)
    setattr(args, "slot_id", slot_id)
    setattr(args, "flowcell_id", flowcell_id)

    # Check DEPLOY_ENV env var exists if --deploy-env not set
    deploy_env_arg = getattr(args, "deploy_env", None)
    if deploy_env_arg is None:
        # Check for DEPLOY_ENV env var
        deploy_env_var = os.environ["DEPLOY_ENV"]
        if deploy_env_var is None:
            logger.error("--deploy-env arg not set and DEPLOY_ENV environment variable is also not set.")
            sys.exit(1)
        elif deploy_env_var not in ["dev", "prod"]:
            logger.error("DEPLOY_ENV environment variable must be set to 'dev' or 'prod'. Alternatively"
                         "specify with --deploy-env on commandline")
            sys.exit(1)
        else:
            setattr(args, "deploy_env", deploy_env_var)

    # New the logger
    set_logger(SCRIPT_DIR, SCRIPT, getattr(args, "deploy_env"))

    # Check directories exists
    # Checking raw base directory exists
    raw_data_base_dir_arg = getattr(args, "raw_data_base_dir", None)
    if raw_data_base_dir_arg is None:
        raw_data_base_dir_arg = NOVASTOR_RAW_BCL_DIR[getattr(args, "deploy_env")]
        # Take from globals
        logger.debug("--raw-data-base-dir not specified. Using globals val {}".format(raw_data_base_dir_arg))
    raw_data_base_dir_path = Path(raw_data_base_dir_arg)
    # Check bcl directory exists
    if not raw_data_base_dir_path.is_dir():
        logger.error("--raw-data-base-dir directory {} does not exist".format(raw_data_base_dir_arg))
        sys.exit(1)
    # Don't write back yet since we also extend this by the instrument name and run folder path
    raw_data_base_dir_path = raw_data_base_dir_path / INSTRUMENT_NAMES[machine_id]
    # Create base directory
    if not raw_data_base_dir_path.is_dir():
        logger.error("Could not find directory {}".format(raw_data_base_dir_path))
        sys.exit(1)
    setattr(args, "raw_data_base_dir", raw_data_base_dir_path)
    # Now create the raw_data_run_dir attribute
    raw_data_run_dir_path = raw_data_base_dir_path / run_folder_arg
    # Check directory exists
    if not raw_data_run_dir_path.is_dir():
        logger.error("Could not find directory{}".format(raw_data_run_dir_path))
    setattr(args, "raw_data_run_dir", raw_data_run_dir_path)

    # We use this along with the 'failed' attribute to collect the sample sheets
    # Check run dir
    if getattr(args, "failed_run", False):
        # Use the default sample sheet
        samplesheet_path = raw_data_run_dir_path / "SampleSheet.csv"
        # Check samplesheet_path exists
        if not samplesheet_path.is_file():
            logger.error("--failed-run set to true {} should exist".format(samplesheet_path))
            sys.exit(1)
        # Set attribute as a list
        setattr(args, "samplesheet_paths", [samplesheet_path])
    else:
        # Find the custom csvs
        samplesheet_paths = list(raw_data_run_dir_path.glob("SampleSheet.*.csv"))

        # Ensure the list is greater than 1
        if len(samplesheet_paths) == 0:
            logger.error("No samplesheets were found in {} matching the pattern:"
                         " 'SampleSheet.*.csv'".format(raw_data_run_dir_path))
            sys.exit(1)

        samplesheet_paths_with_override_cycles_midfix = []

        # For each path, check the override cycles midfix
        for samplesheet_path in samplesheet_paths:
            # Get override cycles midfix segment
            override_cycles_re_obj = re.compile(r"SampleSheet.(\S+).csv").fullmatch(str(samplesheet_path.name))
            if override_cycles_re_obj is None:
                logger.warning("Skipping samplesheet {} as it doesn't have an 'override cycles' midfix".
                               format(samplesheet_path))
                continue
            override_cycles_midfix = override_cycles_re_obj.group(1)
            # Split by underscores
            for override_cycles_segment in override_cycles_midfix.split("_"):
                if OVERRIDE_CYCLES_OBJS["cycles_full_match"].fullmatch(override_cycles_segment) is None:
                    # Place a warning
                    logger.warning("Skipping samplesheet {} as it doesn't have the correct override cycles midfix."
                                   "Segment \"{}\" isn't a valid override cycles segment"
                                   .format(samplesheet_path, override_cycles_segment))
                    break
            else:
                samplesheet_paths_with_override_cycles_midfix.append(samplesheet_path)

        # Check at least one sample was appended
        if len(samplesheet_paths_with_override_cycles_midfix) == 0:
            logger.error("Could not find any samplesheets with the correct SampleSheet.<override_cycles>.csv pattern")
            sys.exit(1)

        # Set attribute
        setattr(args, "samplesheet_paths", samplesheet_paths_with_override_cycles_midfix)

    # Checking bc2fastq-base-dir exists
    bcl2fastq_base_dir_arg = getattr(args, "bcl2fastq_base_dir", None)
    if bcl2fastq_base_dir_arg is None:
        bcl2fastq_base_dir_arg = NOVASTOR_FASTQ_OUTPUT_DIR[getattr(args, "deploy_env")]
        # Take from globals
        logger.debug("--bcl2fastq-base-dir not specified. Using globals val {}".format(bcl2fastq_base_dir_arg))
    bcl2fastq_base_dir_path = Path(bcl2fastq_base_dir_arg)
    # Check parent exists
    if not bcl2fastq_base_dir_path.is_dir():
        logger.error("Directory for --bcl2fastq-base-dir arg - {} does not exist".format(bcl2fastq_base_dir_arg))
        sys.exit(1)
    # Write back as a path object
    setattr(args, "bcl2fastq_base_dir", bcl2fastq_base_dir_path)

    # Now create the bcl2fastq_run_dir attribute
    bcl2fastq_run_dir_path = bcl2fastq_base_dir_path / run_folder_arg
    if not bcl2fastq_run_dir_path.is_dir():
        logger.error("Could not find {} inside --bcl2fastq-base-dir arg".format(run_folder_arg))
    # Write as a path object
    setattr(args, "bcl2fastq_run_dir", bcl2fastq_run_dir_path)

    # Add fastq_hpc_run_dir arg
    fastq_hpc_base_dir_arg = getattr(args, "fastq_hpc_base_dir", None)
    if fastq_hpc_base_dir_arg is None:
        fastq_hpc_base_dir_arg = FASTQ_S3_BUCKET[getattr(args, "deploy_env")]
        # Take from globals
        logger.debug("--fastq-hpc-base-dir not specified. Using globals val {}".format(fastq_hpc_base_dir_arg))
    fastq_hpc_base_dir_path = Path(fastq_hpc_base_dir_arg)
    fastq_hpc_run_dir_path = fastq_hpc_base_dir_path / run_folder_arg
    setattr(args, "fastq_hpc_run_dir", fastq_hpc_run_dir_path)

    # Checking csv-outdir exists
    csv_outdir_arg = getattr(args, "csv_outdir", None)
    csv_outdir_path = Path(csv_outdir_arg)
    # Check csv_outdir exists
    if not csv_outdir_path.is_dir():
        logger.error("Error - csv output directory does not exist. Exiting")
        sys.exit(1)
    # Write back as path object
    setattr(args, "csv_outdir", csv_outdir_path)

    # Check creds_file is a file
    creds_file_arg = getattr(args, "creds_file", None)
    update_local_lims_arg = getattr(args, "update_local_lims", None)
    skip_lims_update_arg = getattr(args, "skip_lims_update", False)

    if update_local_lims_arg is not None:
        if not Path(update_local_lims_arg).is_file():
            logger.error("Could not find file from --update-local-lims: \"{}\"".format(update_local_lims_arg))
    elif creds_file_arg is not None:
        if not Path(creds_file_arg).is_file():
            logger.error("Could not find file from --creds-file arg: \"{}\"".format(creds_file_arg))
            sys.exit(1)

    # Set lims and trackingsheet values based on deploy env
    lab_spreadsheet_id = LAB_SPREAD_SHEET_ID[args.deploy_env]
    lims_spreadsheet_id = LIMS_SPREAD_SHEET_ID[args.deploy_env]

    setattr(args, "lab_spreadsheet_id", lab_spreadsheet_id)
    setattr(args, "lims_spreadsheet_id", lims_spreadsheet_id)

    # Return args
    return args


def get_run_attributes_from_run_name(run_name):
    """
    Use the run regex obj to get the required run attributes
    :param run_name:
    :return:
    """
    run_regex_obj = RUN_REGEX_OBJS["run"].fullmatch(run_name)

    # Run date in YYMMDD format
    run_date = datetime.strptime(run_regex_obj.group(1), '%y%m%d').strftime('%Y-%m-%d')

    # Machine ID either A01052 or A00130
    machine_id = run_regex_obj.group(2)

    # Run Number - Zero-Filled Four Digit Number
    # Convert to int for entry into excel
    run_number = int(run_regex_obj.group(3))

    # Slot/Cartridge ID - either A or B
    slot_id = run_regex_obj.group(4)

    # Flowcell ID - usually ends in DRXX, DRXY, DSXX or DMXX
    flowcell_id = run_regex_obj.group(5)

    return run_date, machine_id, run_number, slot_id, flowcell_id


def get_lims_row(sample, args):
    """
    Get the lims row to create excel sheet
    :param sample:
    :param args:
    :return:
    """

    fastq_pattern = Path(sample.project) / \
                      sample.unique_id / \
                      "{}.fastq.gz".format(sample.library_id)

    num_fastq_files = len(list(args.bcl2fastq_run_dir.glob(str(fastq_pattern))))

    s3_fastq_pattern = args.fastq_hpc_run_dir / \
                       sample.project / \
                       sample.unique_id / \
                       "{}.fastq.gz".format(sample.library_id)

    lims_data_row = [
        args.runfolder,  # illumina_id
        args.run_number,  # run
        args.run_date,  # timestamp
        sample.library_series[METADATA_COLUMN_NAMES["subject_id"]],  # subject_id
        sample.library_series[METADATA_COLUMN_NAMES["sample_id"]],  # sample_id
        sample.library_series[METADATA_COLUMN_NAMES["library_id"]],  # library_id
        sample.library_series[METADATA_COLUMN_NAMES["external_subject_id"]],  # external_subject_id
        sample.library_series[METADATA_COLUMN_NAMES["external_sample_id"]],  # external_sample_id
        "-",  # FIXME "external_library_id"
        sample.library_series[METADATA_COLUMN_NAMES["sample_name"]],  # sample_name
        sample.library_series[METADATA_COLUMN_NAMES["project_owner"]],  # project_owner
        sample.library_series[METADATA_COLUMN_NAMES["project_name"]],  # project_name
        "-",  # FIXME "project_custodian"
        sample.library_series[METADATA_COLUMN_NAMES["type"]],  # type
        sample.library_series[METADATA_COLUMN_NAMES["assay"]],  # assay
        sample.library_series[METADATA_COLUMN_NAMES["override_cycles"]],  # override_cycles
        sample.library_series[METADATA_COLUMN_NAMES["phenotype"]],  # phenotype
        sample.library_series[METADATA_COLUMN_NAMES["source"]],  # source
        sample.library_series[METADATA_COLUMN_NAMES["quality"]],  # quality
        "-",  # FIXME "topup"
        "-",  # FIXME "SecondaryAnalysis"
        sample.library_series[METADATA_COLUMN_NAMES["secondary_analysis"]],  # workflow
        '-',  # tags
        str(s3_fastq_pattern),  # fastq
        num_fastq_files,  # number_fastqs
        '-',  # FIXME results
        '-',  # trello
        '-',  # notes
        '-'  # 'To-Do'
    ]

    return lims_data_row


def main():
    args = get_args()
    # Check args
    args = set_args(args)

    # Initialise sample sheets
    logger.debug("Loading the sample sheets")
    samplesheets = [SampleSheet(samplesheet_path=samplesheet_path)
                    for samplesheet_path in args.samplesheet_paths]

    # Get the years from the sample sheet
    logger.debug("Getting the years of samples used from the samplesheets")
    years = set()
    for samplesheet in samplesheets:
        years_i = get_years_from_samplesheet(samplesheet)
        for year in years_i:
            years.add(year)

    # Loading the appropriate library tracking sheet for the run year
    logger.debug("Loading library tracking data.")
    library_tracking_spreadsheet = collections.defaultdict()  # dict of sheets as dataframes
    for year in years:
        library_tracking_spreadsheet[year] = get_library_sheet_from_google(args.lab_spreadsheet_id, year)

    # Initialise data rows
    lims_data_rows = []

    for samplesheet in samplesheets:
        for sample in samplesheet:
            # Get sample metadata
            sample.set_metadata_row_for_sample(library_tracking_spreadsheet=library_tracking_spreadsheet)
            lims_data_rows.append(get_lims_row(sample, args))

    # Convert to pandas dataframe
    lims_data_df = pd.DataFrame(lims_data_rows, columns=LIMS_COLUMNS.values())

    # Drop duplicate rows - can occur with 10X data
    lims_data_df = lims_data_df.drop_duplicates()

    # Write lims data df to csv if requested
    if getattr(args, "write_csv", False):
        output_file = args.csv_outdir / "{}-{}".format(args.runfolder, "lims-sheet.csv")
        lims_data_df.to_csv(output_file, index=False, header=True, sep=",", quoting=csv.QUOTE_MINIMAL)

    if getattr(args, "skip_lims_update", False):
        logger.info("Skipping Google LIMS update!")
    elif getattr(args, "update_local_lims", False):
        logger.info("Writing {} records to local excel file".format(lims_data_df.shape[0]))
        write_to_local_lims(excel_file=args.update_local_lims,
                            data_df=lims_data_df,
                            failed_run=args.failed_run)
    else:
        logger.info(f"Writing {lims_data_df.shape[0]} records to Google LIMS {args.lims_spreadsheet_id}")
        write_to_google_lims(keyfile=args.creds_file,
                             lims_spreadsheet_id=args.lims_spreadsheet_id,
                             data_rows=lims_data_df,
                             failed_run=args.failed_run)

    logger.info("All done.")


SCRIPT = Path(__file__)
SCRIPT_DIR = SCRIPT.parent
SCRIPT_NAME = SCRIPT.name
logger = set_basic_logger()

if __name__ == "__main__":
    main()

