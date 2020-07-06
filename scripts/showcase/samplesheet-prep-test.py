#!/usr/bin/env python3
import os
import pandas as pd
import argparse
import sys
from pathlib import Path
import re
import logging

# Globals
HEADER_LINE_PRECURSOR = "[Data]"  # Used to separate metadata from samplesheet info
OMITTED_YEAR_SHEETS = ["2018"]  # Has a different number of columns to following years
# Head rows that need to be changed for V2 sample sheets
V2_METADATA_COLUMN_CHANGES = {"Adapter": "AdapterRead1"}
# Column names that need to be changed for V2 sample sheets
V2_COLUMN_CHANGES = {'I7_Index_ID': 'I7_Index', 'I5_Index_ID': 'I5_Index'}
# Key - Method used to process samples of type 'value'
# Value - list of sample types subject to the modification of type 'key'
VALID_SAMPLE_TYPES = {"TSO500": ["TSO"],  # Add two extra columns
                      "V2": ["WGS", "WTS"]}  # Change header and indexes

# Set logs
LOGGER_STYLE = '%(asctime)s - %(levelname)-8s - %(funcName)-20s - %(message)s'
CONSOLE_LOGGER_STYLE = '%(funcName)-12s: %(levelname)-8s %(message)s'
LOGGER_DATEFMT = '%y-%m-%d %H:%M:%S'
THIS_SCRIPT_NAME = "SAMPLESHEET SPLITTER"


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
    parser.add_argument("--sample-sheet", "--samplesheet", "-s", type=str, required=True, dest="sample_sheet")
    parser.add_argument("--tracking-sheet", "--trackingsheet", "-t", type=str, required=True, dest="tracking_sheet")
    parser.add_argument("--output-path", "--outputPath", "-o", type=str, required=True, dest="output_path")

    sample_params_args = parser.add_argument_group("Parameters for filtering out samples."
                                                   "If --sample-type, --index-legnth or --index2length"
                                                   "are used. A file named SampleSheet.csv will be output."
                                                   "If the --all parameter is used, then each file named will be "
                                                   "distinguished with the following notation"
                                                   "SampleSheet_<sample_type>.<index-length>.<index2-length>.csv")
    sample_params_args.add_argument("--sample-type", type=str, required=False, default='WGS',
                                    help="Type of samples we wish to keep")
    sample_params_args.add_argument("--index-length", type=int, required=False, default=8,
                                    help="The length of the i7 index of samples we wish to keep")
    sample_params_args.add_argument("--index2-length", type=int, required=False, default=8,
                                    help="The length of the i5 index of samples we wish to keep")
    sample_params_args.add_argument("--all", action='store_true', default=False,
                                    help="Produce combinations of all samples in the samplesheet."
                                         "Cannot be used in combination with any other sample group parameters "
                                         "(--sample-type, --index-length, --index2-length)")

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
    if not Path(getattr(args, "sample_sheet")).is_file():
        logger.info("Sample sheet does not exist, exiting")
        sys.exit(1)

    # Check tracksheet is a real file
    if not Path(getattr(args, "tracking_sheet")).is_file():
        logger.info("Tracking sheet does not exist, exiting")
        sys.exit(1)

    # Check output file is writable
    output_dir = os.path.normpath(getattr(args, "output_path"))
    if not Path(output_dir).is_dir():
        logger.info("Creating output folder")
        create_output_dir(output_dir)

    # Check that the '--all' and other args follow conventions.
    all_arg = getattr(args, 'all')
    if all_arg:
        logger.info("Setting sample-type, index and index2 all to none since the --all parameter was specified")
        setattr(args, "sample_type", None)
        setattr(args, "index_length", None)
        setattr(args, "index2_length", None)

    return args


def create_output_dir(output_dir):
    """
    param: output_dir: path to the output directory
    """
    # create output directory if it does not exist
    os.makedirs(output_dir, exist_ok=True)


def get_start_row(sample_sheet):
    """
    Find on which line [Data] exists.
    :param sample_sheet: path to the samplesheet
    :return: An integer specifying which row the [Data] header is on.
    """

    # Iterate through lines - return line number that contains the header line
    with open(sample_sheet, 'r') as samplesheet_fh:
        for line_number, line in enumerate(samplesheet_fh.readlines()):
            if line.strip().startswith(HEADER_LINE_PRECURSOR):
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
            index_len           The length of the first index - used in groupings
            index2_len          The length of the second index - using in groupings
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

    # Strip Ns at the end of indexes
    sample_sheet_df['index'] = sample_sheet_df['index'].apply(lambda x: x.rstrip("N"))
    sample_sheet_df['index2'] = sample_sheet_df['index2'].apply(lambda x: x.rstrip("N"))

    # Add lengths
    sample_sheet_df['index_len'] = sample_sheet_df['index'].apply(lambda x: len(x))
    sample_sheet_df['index2_len'] = sample_sheet_df['index2'].apply(lambda x: len(x))

    return sample_sheet_header_rows, sample_sheet_df


def convert_sample_sheet_header_to_v2(sample_sheet_header_rows):
    """
    Given a list of replacements, replace each line with it's replacement

    Parameters
    ----------
    sample_sheet_header_rows : list of header rows

    Returns
    ----------
    A list of header rows with modified content as per V2_METADATA_COLUMN_CHANGES
    """
    sample_sheet_header_rows_new = []
    for row in sample_sheet_header_rows:
        # Initialise new row
        new_row = row
        for old_value, new_value in V2_METADATA_COLUMN_CHANGES.items():
            new_row = re.sub(old_value + ",", new_value + ",", new_row)
        sample_sheet_header_rows_new.append(new_row)
    return sample_sheet_header_rows_new


def convert_sample_sheet_to_v2(sample_sheet_df):
    """
    Convert to samplesheet v2,

    Parameters
    ----------
    sample_sheet_df : pd.DataFrame

    Returns
    -------
    sample_sheet_df : pd.DataFrame where Type and Sample_Type have been dropped, and indexes renamed
    """

    sample_sheet_df = sample_sheet_df.\
        drop(columns=["Type", "Sample_Type"]).\
        rename(columns=V2_COLUMN_CHANGES)
    return sample_sheet_df


def convert_sample_sheet_to_tso500(sample_sheet_df):
    """
    Convert sample sheet to tso500 dataset

    Parameters
    ----------
    sample_sheet_df : pd.DataFrame

    Returns
    --------
    sample_sheet_df : pd.DataFrame with new columns Pair_ID and Sample_Type truncated
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
    Truncate the tracking_sheet_df to just the Sample_ID and the type, then run a merge on the two data frames

    Parameters
    ----------
    tracking_sheet_df : pd.DataFrame with columns Type and Sample_ID (SampleSheet)
    sample_sheet_df : pd.DataFrame

    Returns
    -------
    sample_sheet_df : pd.DataFrame with the additional column 'Type'
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

    slimmed_tracking_df['Type'] = slimmed_tracking_df['Sample_Type'].apply(lambda x:
                                                                           'TSO' if x.startswith("TSO") else x)

    # Merge and return the data frames with the 'Type included
    return pd.merge(sample_sheet_df, slimmed_tracking_df, on='Sample_ID', how='left')


def modify_sample_sheet(sample_sheet_header_rows, sample_sheet_df, sample_type):
    """
    Massive if else function based on the third parameter (sample_type)

    Parameters
    ----------
    sample_sheet_header_rows : list of rows used to create the sample sheet header
    sample_sheet_df : pd.DataFrame with a unique sample index information per lane per row
    sample_type : type of sample we use to modify the header or the sample sheet

    Returns
    -------
    modify_sample_header_rows : list of rows used to create the header
    modified_sample_sheet_df : pd.DataFrame modified as per sample_type below
    """

    # Convert VALID_SAMPLE_TYPES dict into a data frame
    valid_sample_types_df = pd.DataFrame.from_dict(VALID_SAMPLE_TYPES, orient='index').transpose()
    """
    example output:
        TSO500  V2
    0   TSO     WGS
    1   None    WTS
    """

    # Get mod strategy from sample_type by finding columns in df that match the sample type
    modification_strategies = valid_sample_types_df[valid_sample_types_df.eq(sample_type)].\
        dropna(axis='columns', how='all').columns.tolist()

    # Initialise modified content as original content
    modify_sample_header_rows = sample_sheet_header_rows.copy()
    modified_sample_sheet_df = sample_sheet_df.copy()

    # Check length of matches
    if len(modification_strategies) < 1:
        logger.warning("Warning we couldn't figure out what to do with "
                       "this dataset of type '{}', so we're leaving it as is".format(sample_type))
        # Perform basic reset of sample sheet
        modified_sample_sheet_df = modified_sample_sheet_df.drop(columns=["Sample_Type", "Type", "index_len", 'index2_len'])
    elif len(modification_strategies) > 1:
        logger.info("Found multiple modification strategies for {}. Completing in the following order: {}".format(
            sample_type, ', '.join(modification_strategies)
        ))

    # Iterate through each 'strategy'
    for modification_strategy in modification_strategies:
        if modification_strategy == "TSO500":
            # No changes to header rows required.
            # Add two extra columns to sample-sheet
            modified_sample_sheet_df = convert_sample_sheet_to_tso500(modified_sample_sheet_df)
        elif modification_strategy == "V2":
            # Rename adapter key
            modify_sample_header_rows = convert_sample_sheet_header_to_v2(modify_sample_header_rows)
            # Drop 'type' columns and rename indexes
            modified_sample_sheet_df = convert_sample_sheet_to_v2(modified_sample_sheet_df)
        else:
            logger.error("Unsure what to do, matched a modification strategy "
                         "but no indication on how to modify samplesheet")
            sys.exit(1)

    return modify_sample_header_rows, modified_sample_sheet_df


def write_sample_sheets(sample_sheet_header_rows, sample_sheet_df, sample_sheet_dir,
                        sample_type=None, index_len=None, index2_len=None):
    """
    Perform a group-by based on type, append this to the prefix and set as the output

    Parameters
    ----------
    sample_sheet_header_rows : list of lines used to create the sample sheet header
    sample_sheet_df : pd.DataFrame with sample information per row
    sample_sheet_dir : Path output directory to put SampleSheet_<Type>.csv
    sample_type : A specific sample to filter by
    index_len : A specific index length to filter by
    index2_len : A specific index2 length to filter by
    """
    logger.info("Writing out sample sheets")

    # Filter sample sheet by sample
    if sample_type is not None:
        sample_sheet_df = sample_sheet_df.query("Type=='{}'".format(sample_type))
    if sample_sheet_df.shape[0] == 0:
        logger.error("After filtering for type '{}' we ended up with no rows in the sample sheet".format(sample_type))
        sys.exit(1)

    # Filter sample sheet by index length
    if index_len is not None:
        sample_sheet_df = sample_sheet_df.query("index_len=={}".format(index_len))
    if sample_sheet_df.shape[0] == 0:
        logger.error("After filtering for index of len '{}' we ended up with no rows in the sample sheet".format(index_len))
        sys.exit(1)

    # Filter sample sheet by index2 length
    if index2_len is not None:
        sample_sheet_df = sample_sheet_df.query("index2_len=={}".format(index_len))
    if sample_sheet_df.shape[0] == 0:
        logger.error("After filtering for index2 of len '{}' we ended up with no rows in the sample sheet".format(
            index2_len))
        sys.exit(1)

    for (sample_type, index_len, index2_len), sample_sheet_type_df in sample_sheet_df.groupby(['Type', 'index_len', 'index2_len']):
        # Modify the sample-sheet
        modified_sample_header_rows, modified_sample_sheet_df = modify_sample_sheet(
            sample_sheet_header_rows=sample_sheet_header_rows,
            sample_sheet_df=sample_sheet_type_df,
            sample_type=sample_type)

        if sample_type is not None and index_len is not None and index2_len is not None:
            output_file = sample_sheet_dir / "SampleSheet.csv"
        else:
            # --all has been set
            # Set the output file name
            # Based on "SampleSheet_<type>.<index>.<index2>.csv" syntax
            output_file = sample_sheet_dir / "SampleSheet_{}.{}.{}.csv".format(sample_type, index_len, index2_len)

        # Write out the sample sheet
        logger.info("Writing out type {} to {} - containing {} samples".format(
            sample_type, output_file, sample_sheet_type_df.shape[0]))

        # Write out sample sheet
        with open(output_file, 'w') as sample_sheet_output_h:
            # Write out the header rows
            sample_sheet_output_h.writelines(modified_sample_header_rows)
            # Write out [Data]
            sample_sheet_output_h.write("{}\n".format(HEADER_LINE_PRECURSOR))
            # Write out sample sheet
            modified_sample_sheet_df.to_csv(sample_sheet_output_h, sep=",", header=True, index=False)


def main():
    """
    Split sample sheets by type - write to separate files
    """

    # Get args
    args = get_args()

    # Check said args
    args = check_args(args)

    # Read in the samplesheet
    sample_sheet_header_rows, sample_sheet_df = read_sample_sheet(sample_sheet=Path(getattr(args, "sample_sheet")))

    # Read in the tracking sheet
    tracking_sheet_df = read_tracking_sheet(tracking_sheet=Path(getattr(args, "tracking_sheet")))

    # Merge tracking sheet with sample sheet
    sample_sheet_df = add_sample_type_to_sample_sheet(tracking_sheet_df=tracking_sheet_df,
                                                      sample_sheet_df=sample_sheet_df)

    # Write out the sample sheets
    write_sample_sheets(sample_sheet_header_rows=sample_sheet_header_rows,
                        sample_sheet_df=sample_sheet_df,
                        sample_sheet_dir=Path(getattr(args, "output_path")),
                        sample_type=args.sample_type,
                        index_len=args.index_length,
                        index2_len=args.index2_length)


if __name__ == "__main__":
    main()
