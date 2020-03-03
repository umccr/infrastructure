#!/usr/bin/env python

import os
import argparse
import pandas as pd
from pathlib import Path
import logging
import sys

"""
Objective:
Create a set of directories for each sample pair in the run containing
1. A comma separated file for the tumor sample named (<sample_id>.tumor.csv)
2. A comma separated file for the normal sample named (<sample_id>.normal.csv)
Each row in each file represents a fastq pair for a given lane.

Inputs:
a dragen fastq list in csv format, 
a metadata tracking sheet

Method:


"""

# Set globals
OMITTED_YEAR_SHEETS = ["2018"]  # Has a different number of columns to following years
OUTPUT_COLUMNS = ["RGID", "RGSM", "RGLB", "Lane", "Read1File", "Read2File"]
METADATA_COLUMNS = ["Sample ID (SampleSheet)", "SampleID", "Phenotype"]

# Set logs
LOGGER_STYLE = '%(asctime)s - %(levelname)-8s - %(funcName)-20s - %(message)s'
CONSOLE_LOGGER_STYLE = '%(funcName)-12s: %(levelname)-8s %(message)s'
LOGGER_DATEFMT = '%y-%m-%d %H:%M:%S'
THIS_SCRIPT_NAME = "SAMPLESHEET SPLITTER"


class Sample:

    def __init__(self, sample_name, sample_df):
        """
        Initialise the sample object
        Parameters
        ----------
        sample_name: str Name of the sample
        sample_df: pd.DataFrame
        """

        self.name = sample_name
        self.df = sample_df

        # Initialise other future attributes (helps with code completion)
        self.output_path = None  # Output path / sample name
        self.tumor_df = None  # Data frame to write out tumor fastqs
        self.normal_df = None  # Data frame to write out normal fastqs

    def set_output_path(self, output_path):
        """
        Given an external output path, add in the name
        Parameters
        ----------
        output_path: Path

        Returns
        -------
        """

        sample_output_path = output_path / self.name

        # Ensure path exists
        sample_output_path.mkdir(exist_ok=True)

        # Assign
        self.output_path = sample_output_path

    def split_df_into_tumor_and_normal(self):
        """
        Given a sample_df, split into tumor and normal samples

        Returns
        -------
        tumor_df: pd.DataFrame
        normal_df: pd.DataFrame
        """

        tumor_df = self.df.query("Phenotype=='tumor'").filter(items=OUTPUT_COLUMNS)
        normal_df = self.df.query("Phenotype=='normal'").filter(items=OUTPUT_COLUMNS)

        return tumor_df, normal_df

    def write_sample_csvs_to_file(self):
        """
        Given an sample name, a tumor data frame, a normal data frame and an output path,
        write a file called <output_path>/<sample_name>/<sample_name>_tumor.csv from the tumor data frame,
        and a file called <output_path>/<sample_name>/<sample_name>_normal.csv from the normal data frame

        Returns
        -------

        """

        # Set output paths
        tumor_output_path = self.output_path / "{}_tumor.csv".format(self.name)
        normal_output_path = self.output_path / "{}_normal.csv".format(self.name)

        # Write to csv
        self.tumor_df.to_csv(tumor_output_path, index=False)
        self.normal_df.to_csv(normal_output_path, index=False)


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
            sample_sheet
            output_dir
            tracking_sheet
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--samplesheet", "--sample-sheet", "-i",
                        type=str, required=True, dest="sample_sheet",
                        help="The samplesheet output from the dragen bcl convert command")
    parser.add_argument("--trackingsheet", "--tracking-sheet", "-t",
                        type=str, required=True, dest="tracking_sheet",
                        help="The metadata excel spreadsheet")
    parser.add_argument("--outputDir", "--output-dir", "-o",
                        type=str, required=True, dest="output_dir",
                        help="The output directory which will contain a list of subdirectories")

    args = parser.parse_args()

    return args


def check_args(args):
    """

    Parameters
    ----------
    args:
        Attributes:
            sample_sheet: str
            tracking_sheet: str
            output_dir: str

    Returns
    -------
    args
        Attributes:
            sample_sheet: Path (File)
            tracking_sheet: Path (File)
            output_dir: Path (dir)
    """
    # Check samplesheet exists
    sample_sheet_path = Path(os.path.normpath(getattr(args, "sample_sheet")))
    setattr(args, "sample_sheet", sample_sheet_path)
    if not sample_sheet_path.is_file():
        logger.error("Could not find sample sheet at {}, exiting".format(
            sample_sheet_path))
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


def read_samplesheet(sample_sheet_path):
    """
    Read in the sample sheet (output from the dragen bcl convert)


    Parameters
    ----------
    sample_sheet_path

    Returns
    -------
    sample_sheet_df: pd.Dataframe with the following columns
        =========    =======================================
        RGID         i7Index.i5Index.Lane
        RGSM         Sample Name as on the sample sheet
        RGLB         Library ID (Set to Unknown Library)
        Lane         Lane ID
        Read1File    Path to Read 1 File
        Read2File    Path to Read 2 File
    """
    sample_sheet_df = pd.read_csv(sample_sheet_path, header=0)

    return sample_sheet_df


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


def update_sample_objects(samples, output_path):
    """
    Given a list of sample objects, run the necessary internal functions to update attributes
    Parameters
    ----------
    samples
    output_path: Path

    Returns
    -------

    """

    for sample in samples:
        # Set / create the output path for each sample
        sample.set_output_path(output_path)
        # Assign the tumor df and the normal df for each sample
        sample.tumor_df, sample.normal_df = sample.split_df_into_tumor_and_normal()


def merge_sample_sheet_and_tracking_sheet(sample_sheet_df, metadata_df):
    """
    Merge sample sheet and tracking sheet
    Parameters
    ----------
    sample_sheet_df: pd.DataFrame
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

    slimmed_metadata_df = metadata_df.filter(items=METADATA_COLUMNS).\
                              rename(columns={"Sample ID (SampleSheet)": "RGSM"}),

    merged_df = pd.merge(sample_sheet_df, slimmed_metadata_df,
                         on="RGSM", how='left')

    # Check for missing phenotypes in samples
    if merged_df['Phenotype'].isna().any():
        logger.warning("Could not retrieve the phenotype information for samples {}".format(
            ', '.join(merged_df.query("Phenotype.isna()")['RGSM'].tolist())
        ))

    # Check for missing SampleIDs
    if merged_df['SampleID'].isna().any():
        logger.warning("Could not retrieve the SampleID information for samples {}".format(
            ', '.join(merged_df.query("SampleID.isna()")['RGSM'].tolist())
        ))

    merged_df.dropna(subset=["SampleID", "Phenotype"], inplace=True)

    return merged_df


def write_data_frames(samples):
    """
    Given a list of samples write out the data frames to their respective folders
    Parameters
    ----------
    samples: List of type Sample

    Returns
    -------

    """
    for sample in samples:
        sample.write_sample_csvs_to_file()


# Get logger
initialise_logger()
logger = get_logger()


def main():
    args = get_args()

    args = check_args(args)

    # Read sample sheet
    sample_sheet_df = read_samplesheet(sample_sheet_path=args.sample_sheet)

    # Read tracking sheet
    metadata_df = read_tracking_sheet(tracking_sheet_path=args.tracking_sheet)

    # Merge sample sheet and tracking sheet
    merged_df = merge_sample_sheet_and_tracking_sheet(sample_sheet_df=sample_sheet_df,
                                                      metadata_df=metadata_df)

    # Get samples (as sample objects)
    samples = [Sample(sample_name=sample_name, sample_df=sample_df)
               for sample_name, sample_df in merged_df.groupby("SampleID")]

    # Add sample attributes
    update_sample_objects(samples, output_path=args.output_path)

    # Write out dfs
    write_data_frames(samples)


if __name__ == "__main__":
    main()
