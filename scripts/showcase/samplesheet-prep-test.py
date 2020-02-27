#!/usr/bin/env python3
import os
import pandas as pd
import argparse
import sys
from pathlib import Path
import re
import logging

# Globals
HEADER_LINE_PRECURSOR = "[Data]"
V2_COLUMN_CHANGES = {'I7_Index_ID': 'I7_Index', 'I5_Index_ID': 'I5_Index'}
V2_METADATA_COLUMN_CHANGES = {"Adapter": "AdapterRead1"}
VALID_SAMPLE_TYPES = {"TSO500": ["TSO"],
                      "V2": ["WGS", "WTS"]}
OMITTED_YEAR_SHEETS = ["2018"]

# Set logs
LOGGER_STYLE = '%(asctime)s - %(levelname)-8s - %(funcName)-20s - %(message)s'
CONSOLE_LOGGER_STYLE = '%(funcName)-12s: %(levelname)-8s %(message)s'
LOGGER_DATEFMT = '%y-%m-%d %H:%M:%S'
THIS_SCRIPT_NAME = "SAMPLESHEET TESTER"


def initialise_logger():
    """
    Return the logger in a nice logging format
    :return:
    """
    # Initialise logger
    # set up logging to file - see previous section for more details
    logging.basicConfig(level=logging.DEBUG,
                        format=LOGGER_STYLE,
                        datefmt=LOGGER_DATEFMT)
    # define a Handler which writes INFO messages or higher to the sys.stderr
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    # set a format which is simpler for console use
    formatter = logging.Formatter(CONSOLE_LOGGER_STYLE)
    # tell the handler to use this format
    console.setFormatter(formatter)
    # add the handler to the root logger
    #logging.getLogger('').addHandler(console)


def get_logger():
    """
    Get the name of where this function was called from - return a logging object
    Use a trackback from the inspect to do this
    :return:
    """
    return logging.getLogger(THIS_SCRIPT_NAME)


# Get logger
initialise_logger()
logger = get_logger()


def get_args():
    """
    Read args
    return: argparse dict
    """
    # Initialise parser
    parser = argparse.ArgumentParser()
    # Place arguments
    parser.add_argument("--samplesheet", "-s", type=str, required=True)
    parser.add_argument("--trackingsheet", "-t", type=str, required=True)
    parser.add_argument("--outputFile", "-o", type=str, required=True)

    return parser.parse_args()


def check_args(args):
    """
    Check each of the arguments are legit
    param args: argparse input
        attrs:
            samplesheet
            trackingsheet
            outputFile
    """

    # Check samplesheet is a real file
    if not Path(args.samplesheet).is_file():
        logger.info("Sample sheet does not exist, exiting")
        sys.exit(1)

    # Check tracksheet is a real file
    if not Path(args.trackingsheet).is_file():
        logger.info("Tracking sheet does not exist, exiting")
        sys.exit(1)

    # Check output file is writable
    output_dir = os.path.dirname(os.path.normpath(args.outputFile))
    if not Path(output_dir).is_dir():
        logger.info("Creating output folder")
        create_output_dir(output_dir)


def create_output_dir(output_dir):
    """
    param: output_dir: path to the output directory
    """
    # create output directory if it does not exist
    output_dir = os.path.dirname(output_dir)
    os.makedirs(output_dir, exist_ok=True)


def get_start_row(sample_sheet):
    """
    Find on which line [Data] exists.
    :param sample_sheet: path to the samplesheet
    :return: An integer specifying which row the [Data] header is on.
    """

    backslash_chars = '[]'
    escaped_header_line = ''.join(["\\%s" % char if char in backslash_chars else char
                                   for char in HEADER_LINE_PRECURSOR
                                  ])

    re_pattern = re.compile("^%s(,)*" % escaped_header_line)

    # Iterate through lines - return line number that contains the header line
    with open(sample_sheet, 'r') as samplesheet_fh:
        for line_number, line in enumerate(samplesheet_fh.readlines()):
            if line.strip() == HEADER_LINE_PRECURSOR or re.match(re_pattern, line.strip()):
                break
        else:
            logger.info("Could not find data line")
            sys.exit(1)

    # Return which line we found '[Data]' on
    return line_number


def read_sample_sheet(sample_sheet):
    """
    Read the samplesheet in two parts,
    first part being the header rows, the latter being the samplesheet dataframe
    :param sample_sheet: path to the original sample_sheet
    :return:
        sample_sheet_header_rows: list of header lines
        sample_sheet_df: pd.DataFrame with the following columns
            Dataframe of samplesheet. Data columns are as follows:

            ==========          ==============================================================
            Lane                The Lane ID
            Sample_ID           The ID of the sample (`str`) - required
            Sample_Name         The Name of the sample (`str`) - optional
            Sample_Plate        The plate on which the sample was on (`str`) - optional
            Sample_Well         The well of the plate which the sample was on - optional
            Index_ID            The i7 Index_ID - eg UP01 (`str`) - optional
            index               The i7 nucleotide string of the index - eg TCCGGAGA (`str`) - required
            index2              The i5 nucleotide string of the index - eg AGGATAGG (`str`) - required
            Sample_Type         What type of sample is this - eg DNA (`str) - optional
            Pair_ID             Which pair of samples does this belong to - eg est_Sample_UP01 -
                                this may be the same as Sample_ID - required
            ==========  ==============================================================
    """
    # Find the pivot (The row that contains [Data] that splits the samplesheet from the header
    start_row = get_start_row(sample_sheet)

    logger.info("Reading in sample sheet")

    # Initialise lines that comprise the header rows
    sample_sheet_header_rows = []

    # Read header rows
    with open(sample_sheet, 'r') as sample_sheet_h:
        for i, line in enumerate(sample_sheet_h.readlines()):
            if i < start_row:
                sample_sheet_header_rows.append(line.strip().rstrip(",") + "\n")
                i += 1
            else:
                break

    # Re-read the sample sheet
    sample_sheet_df = pd.read_csv(sample_sheet, skiprows=start_row+1, header=0)

    return sample_sheet_header_rows, sample_sheet_df


def convert_sample_sheet_header_to_v2(sample_sheet_header_rows):
    """
    Given a list of replacements, replace each line with it's replacement
    """
    sample_sheet_header_rows_new = []
    for row in sample_sheet_header_rows:
        new_row = row
        for old, new in V2_METADATA_COLUMN_CHANGES.items():
            new_row = re.sub(old + ",", new + ",", new_row)
        sample_sheet_header_rows_new.append(new_row)
    return sample_sheet_header_rows_new


def convert_sample_sheet_to_v2(sample_sheet_df):
    """
    Convert to samplesheet v2,
    """

    sample_sheet_df = sample_sheet_df.\
        drop(columns=["Type", "Sample_Type"]).\
        rename(columns=V2_COLUMN_CHANGES)
    return sample_sheet_df


def convert_sample_sheet_to_tso500(sample_sheet_df):
    """
    Convert sample sheet to tso500 dataset
    """

    # Add the column ['Pair_ID']
    sample_sheet_df = sample_sheet_df.drop(columns=["Type"]).\
        assign(Pair_ID=lambda x: x.Sample_ID)

    # Format Sample_Type to be stripped of the TSO_ bit
    sample_sheet_df['Sample_Type'] = sample_sheet_df["Sample_Type"].apply(lambda x: re.sub("^TSO_", "", x))

    return sample_sheet_df


def read_tracking_sheet(tracking_sheet):
    """
    Read the tracking sheet
    return:
        tracking_sheet_df: pd.DataFrame with the following columns
            Dataframe of samplesheet. Data columns are as follows:
            ==========                 ==============================================================
            LibraryID
            SampleName
            SampleID
            ExternalSampleID
            SubjectID
            ExternalSubjectID
            Phenotype
            Quality
            Source
            ProjectName
            ProjectOwner
            ExperimentID
            Type
            Assay
            Coverage (X)
            IDT Index , unless stated
            Baymax run#
            Comments
            rRNA
            qPCR ID
            Sample_ID (SampleSheet)
            ==========                ==============================================================
    """

    tracking_sheets = []

    # Initialise in a excel file
    logger.info("Loading excel file")
    xl = pd.ExcelFile(tracking_sheet)

    # Check sheet names - we just want from 2019 onwards
    valid_sheet_names = [sheet_name
                         for sheet_name in xl.sheet_names
                         if sheet_name.isnumeric()
                         and sheet_name not in OMITTED_YEAR_SHEETS]
    if len(valid_sheet_names) == 0:
        logger.error("Could not find any valid sheet names in {}".format(tracking_sheet))
        sys.exit(1)

    # read tracking sheet
    for sheet_name in valid_sheet_names:
        logger.info("Reading sheet %s" % sheet_name)
        tracking_sheets.append(xl.parse(header=0, sheet_name=sheet_name))

    tracking_sheet_df = pd.concat(tracking_sheets)

    return tracking_sheet_df


def add_sample_type_to_sample_sheet(tracking_sheet_df, sample_sheet_df):
    """
    Truncate the tracking_sheet_df to just the Sample_ID and the type, then run a merge on the two dataframes
    """

    # Get the list of samples in the sample sheet
    sample_list = sample_sheet_df['Sample_ID'].unique().tolist()

    # A bit going on here:
    # 1. Slim down the tracking data frame to just the Sample ID and the type of sample.
    # 2. Rename the columns to 'Sample_ID and Sample_Type (the latter is used in the TSO500 sample sheet)
    # 3. Filter to rows only present in this sample sheet
    # 4. Add the column 'Type' that we then group by. TSO_DNA and TSO_RNA are set to TSO
    slimmed_tracking_df = tracking_sheet_df[['Type', 'Sample_ID (SampleSheet)']].\
        rename(columns={"Sample_ID (SampleSheet)": "Sample_ID",
                        "Type": "Sample_Type"}).\
        query("Sample_ID in @sample_list")

    slimmed_tracking_df['Type'] = slimmed_tracking_df['Sample_Type'].apply(lambda x: 'TSO' if x.startswith("TSO") else x)

    # Merge and return the data frames with the 'Type included
    return pd.merge(sample_sheet_df, slimmed_tracking_df, on='Sample_ID', how='left')


def write_sample_sheet(sample_sheet_df, sample_sheet_header_rows, sample_sheet_output_file):
    """
    Given a sample type, a full sample sheet df, and a header row, write out the sample,sheet as a csv file
    """

    with open(sample_sheet_output_file, 'w') as sample_sheet_output_h:
        # Write out the header rows
        sample_sheet_output_h.writelines(sample_sheet_header_rows)
        # Write out [Data]
        sample_sheet_output_h.write("{}\n".format(HEADER_LINE_PRECURSOR))
        # Write out sample sheet
        sample_sheet_df.\
            to_csv(sample_sheet_output_h, sep=",", header=True, index=False)

    # Completed writing of header file


def modify_sample_sheet(sample_sheet_df, sample_sheet_header_rows, sample_type):
    """
    Massive if else function based on the second parameter
    """

    # Get mod strategy from sample_type
    modification_strategy = [mod_strat for mod_strat, sample_types in VALID_SAMPLE_TYPES.items()
                             if sample_type in sample_types]

    if not len(modification_strategy) == 1:
        logger.warning("Warning we couldn't figure out what to do with "
                       "this dataset of type '{}', so we're leaving it as is".format(sample_type))
        modification_strategy = None
    else:
        modification_strategy = modification_strategy[0]

    if modification_strategy == "TSO500":
        # Add two extra columns to sample-sheet
        modified_sample_sheet_df = convert_sample_sheet_to_tso500(sample_sheet_df)
        # No changes to header rows required.
        modify_sample_header_rows = sample_sheet_header_rows
    elif modification_strategy == "V2":
        # Add two extra columns to sample-sheet
        modified_sample_sheet_df = convert_sample_sheet_to_v2(sample_sheet_df)
        # No changes to header rows required.
        modify_sample_header_rows = convert_sample_sheet_header_to_v2(sample_sheet_header_rows)
    else:
        # Perform basic reset
        modified_sample_sheet_df = sample_sheet_df.drop(columns=["Sample_Type", "Type"])
        modify_sample_header_rows = sample_sheet_header_rows

    return modified_sample_sheet_df, modify_sample_header_rows


def write_sample_sheets(sample_sheet_df, sample_sheet_header_rows, sample_sheet_prefix='SampleSheet'):
    """
    Perform a group-by based on type, append this to the prefix and set as the output
    """
    logger.info("Writing out sample sheets")
    for sample_type, sample_sheet_type_df in sample_sheet_df.groupby('Type'):
        # Modify the sample-sheet
        modified_sample_sheet_df, modified_sample_header_rows = modify_sample_sheet(sample_sheet_type_df,
                                                                                    sample_sheet_header_rows,
                                                                                    sample_type)
        # Set the output file name
        output_file = '_'.join([sample_sheet_prefix, sample_type]) + ".csv"

        # Write out the sample sheet
        logger.info("Writing out type {} to {} - containing {} samples".format(
            sample_type, output_file, sample_sheet_type_df.shape[0]))
        write_sample_sheet(modified_sample_sheet_df, modified_sample_header_rows, output_file)


def main():
    """
    Split sample sheets by type - write to separate files
    """

    # Get args
    args = get_args()

    # Check said args
    check_args(args)

    # Read in the samplesheet
    sample_sheet_header_rows, sample_sheet_df = read_sample_sheet(args.samplesheet)

    # Read in the tracking sheet
    tracking_sheet_df = read_tracking_sheet(args.trackingsheet)

    # Merge tracking sheet with sample sheet
    sample_sheet_df = add_sample_type_to_sample_sheet(tracking_sheet_df, sample_sheet_df)

    # Write out the sample sheets
    write_sample_sheets(sample_sheet_df, sample_sheet_header_rows, sample_sheet_prefix=args.outputFile)


if __name__ == "__main__":
    main()
