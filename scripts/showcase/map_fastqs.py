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
1. A comma separated file for the tumour sample named (<sample_id>.tumour.csv)
2. A comma separated file for the normal sample named (<sample_id>.normal.csv)
Each row in each file represents a fastq pair for a given lane.

Inputs:
a dragen fastq list in csv format, 
a metadata tracking sheet

Method:


"""

# Set globals
OMITTED_YEAR_SHEETS = ["2018"]  # Has a different number of columns to following years

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
        self.tumour_df = None  # Data frame to write out tumour fastqs
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

    def split_df_into_tumour_and_normal(self):
        """
        Given a sample_df, split into tumour and normal samples

        Returns
        -------
        tumour_df: pd.DataFrame
        normal_df: pd.DataFrame
        """

        # TODO is Phenotype the right column?
        tumour_df = self.df.query("Phenotype=='tumour'").drop(columns='Phenotype')
        normal_df = self.df.query("Phenotype=='normal'").drop(columns='Phenotype')

        return tumour_df, normal_df

    def write_sample_csvs_to_file(self):
        """
        Given an sample name, a tumour data frame, a normal data frame and an output path,
        write a file called <output_path>/<sample_name>/<sample_name>_tumour.csv from the tumour data frame,
        and a file called <output_path>/<sample_name>/<sample_name>_normal.csv from the normal data frame

        Parameters
        ----------
        sample_name
        tumour_df
        normal_df
        output_path: Path

        Returns
        -------

        """

        # Set output paths
        tumour_output_path = self.output_path / "{}_tumour.csv".format(self.name)
        normal_output_path = self.output_path / "{}_normal.csv".format(self.name)

        # Write to csv
        self.tumour_df.to_csv(tumour_output_path, index=False)
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
    sample_sheet_df:
        # TODO add columns in output
    """
    # TODO is there a header?
    sample_sheet_df = pd.read_csv(sample_sheet_path)

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
        # Assign the tumour df and the normal df for each sample
        sample.tumour_df, sample.normal_df = sample.split_df_into_tumour_and_normal()


def merge_sample_sheet_and_tracking_sheet(sample_sheet_df, metadata_df):
    """
    Merge sample sheet and tracking sheet
    Parameters
    ----------
    sample_sheet_df
    metadata_df

    Returns
    -------
    merged_df: pd.DataFrame
        Columns  # Explore columns

    """
    # TODO which columns are appropriate to bind on?
    # TODO which columns from the metadata are needed to be extracted (and then dropped again when written out)

    return merged_df


def write_data_frames(samples):
    """
    Given a list of samples write out the data frames to their respective folders
    Parameters
    ----------
    samples

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
    # TODO determine right column to group by
    samples = [Sample(sample_name=sample_name, sample_df=sample_df)
               for sample_name, sample_df in merged_df.groupby("SampleName")]

    # Add sample attributes
    update_sample_objects(samples, output_path=args.output_path)

    # Write out dfs
    write_data_frames(samples)


if __name__ == "__main__":
    main()