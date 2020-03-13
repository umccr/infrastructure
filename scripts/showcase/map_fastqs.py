#!/usr/bin/env python

import os
import argparse
import pandas as pd
from pandas.api.types import CategoricalDtype
from pathlib import Path
import logging
import sys

"""
Objective:
Create a set of directories for each sample pair in the run containing
1. A comma separated file for the tumor sample named (<subject_id>.tumor.csv)
2. A comma separated file for the normal sample named (<subject_id>.normal.csv)
Each row in each file represents a fastq pair for a given lane.

Inputs:
a dragen fastq list in csv format, 
a metadata tracking sheet

Method:


"""

# Set globals
OMITTED_YEAR_SHEETS = ["2018"]  # Has a different number of columns to following years
OUTPUT_COLUMNS = ["RGID", "RGSM", "RGLB", "Lane", "Read1File", "Read2File"]
METADATA_COLUMNS = ["LibraryID", "Sample_ID (SampleSheet)", "SampleID", "SubjectID", "Phenotype"]
VALID_PHENOTYPES = ["tumor", "normal"]
PHENOTYPES_DTYPE = CategoricalDtype(categories=VALID_PHENOTYPES,
                                    ordered=False)

# Set logs
LOGGER_STYLE = '%(asctime)s - %(levelname)-8s - %(funcName)-20s - %(message)s'
CONSOLE_LOGGER_STYLE = '%(funcName)-12s: %(levelname)-8s %(message)s'
LOGGER_DATEFMT = '%y-%m-%d %H:%M:%S'
THIS_SCRIPT_NAME = "SAMPLESHEET SPLITTER"

# Regexes
CONTROL_REGEX_MATCH = r'^(?:NTC|PTC)_\w+$'  # https://regex101.com/r/rROljA/1
LIBRARY_TOPUP_REGEX_MATCH = r'^L\d+_(?:topup)\d*$'  # https://regex101.com/r/przpgt/1


class Subject:

    def __init__(self, subject_id, sample_df):
        """
        Initialise the sample object
        Parameters
        ----------
        subject_id: str Name of the subject ID, matches 'SubjectID' in metadata file
        sample_df: pd.DataFrame
        """

        # Subject of origin
        self.subject_id = subject_id

        # Data frame with output information
        self.df = sample_df

        # Initialise other future attributes (helps with code completion)
        self.output_path = None  # Output path / subject id

    def set_output_path(self, output_path):
        """
        Given an external output path, add in the name
        Parameters
        ----------
        output_path: Path

        Returns
        -------
        """

        subject_output_path = output_path / self.subject_id

        # Ensure path exists
        subject_output_path.mkdir(exist_ok=True)

        # Assign
        self.output_path = subject_output_path

    def write_sample_csvs_to_file(self):
        """
        Given an sample name, a tumor data frame, a normal data frame and an output path,
        write a file called <output_path>/<subject_id>/<subject_id>_tumor.csv from the tumor data frame,
        and a file called <output_path>/<subject_id>/<subject_id>_normal.csv from the normal data frame

        Returns
        -------

        """

        # Run each to-csv via a group by
        for phenotype, phenotype_df in self.df.groupby("Phenotype"):
            # Since Phenotype is of type 'Categorical' we go through each level
            # even if it's not present in the data frame.
            # First check we've actually got at least one row before writing
            if phenotype_df.shape[0] == 0:
                # No rows for this phenotype, move on
                continue

            # Set output paths
            output_path = self.output_path / "{}_{}.csv".format(self.subject_id, phenotype)

            # Write to csv
            phenotype_df.filter(items=OUTPUT_COLUMNS).\
                to_csv(output_path, index=False)


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


def get_args():
    """

    Returns
    -------
    args:
        Attributes:
            fastq_csv
            output_dir
            tracking_sheet
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--fastq-csv", "--fastq-csv", "-i",
                        type=str, required=True, dest="fastq_csv",
                        help="The samplesheet output from the dragen bcl convert command")
    parser.add_argument("--trackingsheet", "--tracking-sheet", "-t",
                        type=str, required=True, dest="tracking_sheet",
                        help="The metadata excel spreadsheet")
    parser.add_argument("--outputDir", "--output-dir", "-o",
                        type=str, required=True, dest="output_dir",
                        help="The output directory which will contain a list of subdirectories")

    # Add filter arguments to keep/rule out samples that don't fit the norm
    filter_options_arguments = parser.add_argument_group()

    filter_options_arguments.add_argument("--keep-single-samples",
                                          default=False, action='store_true',
                                          help="Keep samples even if it is missing either "
                                               "the normal or tumor complement")
    filter_options_arguments.add_argument("--keep-top-ups",
                                          default=False, action='store_true',
                                          help="Keep top-up samples")
    filter_options_arguments.add_argument("--keep-control-samples",
                                          default=False, action='store_true',
                                          help="Keep control samples (those starting with NTC and PTC)")

    # Add filter arguments to keep/rule out samples that don't fit the norm
    filter_options_arguments = parser.add_argument_group()

    filter_options_arguments.add_argument("--keep-single-samples",
                                          default=False, action='store_true',
                                          help="Keep samples even if it is missing either "
                                               "the normal or tumor complement")
    filter_options_arguments.add_argument("--keep-top-ups",
                                          default=False, action='store_true',
                                          help="Keep top-up samples")
    filter_options_arguments.add_argument("--keep-control-samples",
                                          default=False, action='store_true',
                                          help="Keep control samples (those starting with NTC and PTC)")

    args = parser.parse_args()

    return args


def check_args(args):
    """

    Parameters
    ----------
    args:
        Attributes:
            fastq_csv: str
            tracking_sheet: str
            output_dir: str

    Returns
    -------
    args
        Attributes:
            fastq_csv: Path (File)
            tracking_sheet: Path (File)
            output_dir: Path (dir)
    """
    # Check samplesheet exists
    fastq_csv_path = Path(os.path.normpath(getattr(args, "fastq_csv")))
    setattr(args, "fastq_csv", fastq_csv_path)
    if not fastq_csv_path.is_file():
        logger.error("Could not find sample sheet at {}, exiting".format(
            fastq_csv_path))
        sys.exit(1)

    # Check tracking sheet exists
    tracking_sheet_path = Path(os.path.normpath(getattr(args, "tracking_sheet")))
    setattr(args, "tracking_sheet", tracking_sheet_path)
    if not tracking_sheet_path.is_file():
        logger.error("Could not find sample sheet at {}, exiting".format(
            tracking_sheet_path))
        sys.exit(1)

    # Check output directory exists
    output_path = Path(os.path.normpath(getattr(args, "output_dir")))
    setattr(args, "output_dir", output_path)
    if not output_path.is_dir():
        logger.info("Creating output directory at {}".format(
            output_path))
        output_path.mkdir()

    return args


def read_samplesheet(fastq_csv_path):
    """
    Read in the sample sheet (output from the dragen bcl convert)


    Parameters
    ----------
    fastq_csv_path

    Returns
    -------
    fastq_df: pd.Dataframe with the following columns
        =========    =======================================
        RGID         i7Index.i5Index.Lane
        RGSM         Sample Name as on the sample sheet
        RGLB         Library ID (Set to Unknown Library)
        Lane         Lane ID
        Read1File    Path to Read 1 File
        Read2File    Path to Read 2 File
    """
    fastq_df = pd.read_csv(fastq_csv_path, header=0)

    return fastq_df


def read_tracking_sheet(tracking_sheet_path):
    """
    Read the tracking sheet
    Returns
    -------
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
    xl = pd.ExcelFile(tracking_sheet_path)

    # Check sheet names - we just want from 2019 onwards
    valid_sheet_names = [sheet_name
                         for sheet_name in xl.sheet_names
                         if sheet_name.isnumeric()
                         and sheet_name not in OMITTED_YEAR_SHEETS]
    if len(valid_sheet_names) == 0:
        logger.error("Could not find any valid sheet names in {}".format(tracking_sheet_path))
        sys.exit(1)

    # read tracking sheet
    for sheet_name in valid_sheet_names:
        logger.info("Reading sheet %s" % sheet_name)
        tracking_sheets.append(xl.parse(header=0, sheet_name=sheet_name))

    tracking_sheet_df = pd.concat(tracking_sheets)

    return tracking_sheet_df


def update_subject_objects(subject, output_path):
    """
    Given a list of subject objects, run the necessary internal functions to update attributes
    Parameters
    ----------
    subject
    output_path: Path

    Returns
    -------

    """

    for subject in subject:
        # Set / create the output path for each subject
        subject.set_output_path(output_path)


def merge_fastq_csv_and_tracking_sheet(fastq_df, metadata_df, keep_single_samples=False, keep_top_ups=False, keep_control_samples=False):
    """
    Merge sample sheet and tracking sheet
    Parameters
    ----------
    fastq_df: pd.DataFrame
    metadata_df: pd.DataFrame

    Returns
    -------
    merged_df: pd.DataFrame
        =========    =======================================
        RGID         i7Index.i5Index.Lane
        RGSM         Sample Name as on the sample sheet
        RGLB         Library ID (Set to Unknown Library)
        Lane         Lane ID
        Read1File    Path to Read 1 File
        Read2File    Path to Read 2 File
        # Extended columns
        SampleID     Identifier of the sample, may be useful if we're running with top ups
        Phenotype    Either 'tumor' or 'normal'

    """
    # Columns to keep

    slimmed_metadata_df = metadata_df.filter(items=METADATA_COLUMNS)

    merged_df = pd.merge(fastq_df, slimmed_metadata_df,
                         left_on="RGSM", right_on="Sample_ID (SampleSheet)",
                         how="left")

    # Ensure Phenotype is either 'tumor' or 'normal'
    merged_df["Phenotype"] = merged_df["Phenotype"].astype(PHENOTYPES_DTYPE)

    # Check for missing SampleIDs - Positive controls sometimes don't have a sample ID
    if merged_df['SampleID'].isna().any():
        logger.warning("Could not retrieve the SubjectID information for samples {}".format(
            ', '.join(merged_df.query("SubjectID.isna()")['Sample_ID (SampleSheet)'].tolist())
        ))

    # Check for missing SubjectIDs
    if merged_df['SubjectID'].isna().any():
        logger.warning("Could not retrieve the SubjectID information for samples {}".format(
            ', '.join(merged_df.query("SubjectID.isna()")['Sample_ID (SampleSheet)'].tolist())
        ))

    # Check for missing phenotypes in samples - could be from an invalid merge or bad name
    if merged_df['Phenotype'].isna().any():
        logger.warning("Could not retrieve the phenotype information for samples {}".format(
            ', '.join(merged_df.query("Phenotype.isna()")['Sample_ID (SampleSheet)'].tolist())
        ))

    # Remove controls (samples that start with PTC or NTC)
    # See the regex magic here: https://regex101.com/r/rROljA/1
    # Str contains explanation here: https://stackoverflow.com/a/44335734/6946787
    # '~' does the negating.

    if not keep_control_samples:
        # Remove control samples
        merged_df.query("~SampleID.str.contains(@CONTROL_REGEX_MATCH, regex=True)", inplace=True)

    if not keep_top_ups:
        # Remove top ups
        merged_df.query("~LibraryID.str.contains(@LIBRARY_TOPUP_REGEX_MATCH, regex=True)", inplace=True)

    # Drop rows with missing values in any of the columns checked for above
    merged_df.dropna(subset=["SampleID", "SubjectID", "Phenotype"], how='any', inplace=True)

    if not keep_single_samples:
        # Only keep samples that have a tumor/normal complement for a given Subject ID
        # Here we group by SubjectID, use nunique to find the number of
        # unique Phenotypes for each SubjectID
        # Revert to frame and reset index, now column SubjectID is the subject ID and
        # Phenotype represents the number of unique phenotypes for a given subject ID
        # We rename the column for clarity
        # Then select only subject IDs whose where the Phenotype column equals two
        subjects_with_pairs = merged_df.groupby("SubjectID")['Phenotype'].nunique().\
            to_frame().\
            reset_index().\
            rename(columns={"Phenotype": "NUniquePhenotypes"}).\
            query("NUniquePhenotypes == 2")['SubjectID'].\
            tolist()

        # Now filter out the original merged_df using the subjects_with_pairs list
        merged_df = merged_df.query("SubjectID in @subjects_with_pairs")

    return merged_df


def write_data_frames(subjects):
    """
    Given a list of samples write out the data frames to their respective folders
    Parameters
    ----------
    subjects: List of type Subject

    Returns
    -------

    """
    for subject in subjects:
        logger.info("Writing csvs for subject {}".format(subject.subject_id))
        subject.write_sample_csvs_to_file()


# Get logger
initialise_logger()
logger = get_logger()


def main():
    logger.info("Getting args")
    args = get_args()
    args = check_args(args)

    # Read sample sheet
    logger.info("Reading sample sheet")
    fastq_df = read_samplesheet(fastq_csv_path=args.fastq_csv)

    # Read tracking sheet
    logger.info("Reading tracking sheet")
    metadata_df = read_tracking_sheet(tracking_sheet_path=args.tracking_sheet)

    # Merge sample sheet and tracking sheet
    logger.info("Merging sample sheet and tracking sheet")
    merged_df = merge_fastq_csv_and_tracking_sheet(fastq_df=fastq_df,
                                                   metadata_df=metadata_df,
                                                   keep_single_samples=args.keep_single_samples,
                                                   keep_top_ups=args.keep_top_ups,
                                                   keep_control_samples=args.keep_control_samples)

    # Get subjects (as Subject objects)
    logger.info("Initialising sample constructs")
    subjects = [Subject(subject_id=sample_name, sample_df=sample_df)
                for sample_name, sample_df in merged_df.groupby("SubjectID")]

    # Add subject attributes
    logger.info("Updating subject attributes")
    update_subject_objects(subjects, output_path=args.output_dir)

    # Write out dfs
    logger.info("Writing out data frames to output path")
    write_data_frames(subjects)


if __name__ == "__main__":
    main()
