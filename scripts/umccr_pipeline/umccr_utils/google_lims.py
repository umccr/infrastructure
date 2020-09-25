#!/usr/bin/env python3

"""
Pull in library and metadata sheet from google
"""

import pandas as pd
from gspread_pandas import Spread
from umccr_utils.globals import METADATA_COLUMN_NAMES, METADATA_VALIDATION_COLUMN_NAMES
from umccr_utils.logger import get_logger
from umccr_utils.errors import ColumnNotFoundError

logger = get_logger()


def get_library_sheet_from_google(lab_spreadsheet_id, year):
    """
    Given the google suite spread sheet id and a year, read in the sheet that matches the 'year' variable
    :param lab_spreadsheet_id:
    :param year:
    :return: library_tracking_spreadsheet_df: pd.DataFrame with the following columns
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
                                                  OverrideCycles
                                                  Workflow
                                                  Coverage (X)
                                                  IDT Index , unless stated
                                                  Run#
                                                  Comments
                                                  rRNA
                                                  qPCR ID
                                                  Sample_ID (SampleSheet)
    """
    logger.info(f"Loading tracking data for year {year}")

    # Import from gsuite
    library_tracking_spreadsheet_df = read_gsuite_excel_file(lab_spreadsheet_id, year)

    # Check columns
    check_lab_metadata_columns(library_tracking_spreadsheet_df)

    # Truncate to size
    library_tracking_spreadsheet_df = remove_blank_rows(library_tracking_spreadsheet_df)

    return library_tracking_spreadsheet_df


def import_library_sheet_validation_from_google(lab_spreadsheet_id):
    """
    Given the google suite spreadsheet id, read in the sheet 'Validation'
    :param lab_spreadsheet_id:
    :return: validation_df: pd.DataFrame with the following columns:
                                Assay
                                PhenotypeValues
                                ProjectNameValues
                                ProjectOwnerValues
                                QualityValues
                                SourceValues
                                TypeValues
                                ValidationRules
    """

    # Import from gsuite
    validation_df = read_gsuite_excel_file(lab_spreadsheet_id, "validation")

    # Check validation columns
    check_validation_metadata_columns(validation_df)

    return validation_df


def get_local_lab_metadata(lab_spreadsheet_path, year):
    """
    Get the local lab metadata
    Returns same columns as the gsuite spreadsheet... well it should
    :param lab_spreadsheet_path:
    :param year:
    :return:
    """

    # Import from gsuite
    library_tracking_spreadsheet_df = read_local_excel_file(lab_spreadsheet_path, year)

    # Check columns
    check_lab_metadata_columns(library_tracking_spreadsheet_df)

    # Truncate to size
    library_tracking_spreadsheet_df = remove_blank_rows(library_tracking_spreadsheet_df)

    return library_tracking_spreadsheet_df


def get_local_validation_metadata(lab_spreadsheet_path):
    """
    Get the local validation columns
    :param lab_spreadsheet_path:
    :return:
    """

    # Import from gsuite
    validation_df = read_local_excel_file(lab_spreadsheet_path, "validation")

    # Check validation columns
    check_validation_metadata_columns(validation_df)

    return validation_df


def read_gsuite_excel_file(gsuite_file_id, sheet_name):
    """
    Read a gsuite file and parse through the sheet name as a pandas dataframe
    :param gsuite_file_id:
    :param sheet_name:
    :return:
    """

    spread = Spread(gsuite_file_id)

    return spread.sheet_to_df(sheet=sheet_name, index=0, header_rows=1, start_row=1)


def read_local_excel_file(local_path, sheet_name):
    """
    Read local excel file and parse through the sheet name as a pandas dataframe
    :param local_path:
    :param sheet_name:
    :return:
    """

    xl = pd.ExcelFile(local_path)

    return xl.parse(sheet_name=sheet_name, header=0)


def check_lab_metadata_columns(lab_metadata_df):
    """
    Check the essential columns of the metadata dataframe are present
    :param lab_metadata_df:
    :return:
    """

    for column_name in METADATA_COLUMN_NAMES:
        logger.debug(f"Checking for column name {column_name}...")
        if column_name not in lab_metadata_df.columns.tolist():
            logger.error(f"Could not find column {column_name}. The file is not structured as expected! Aborting.")
            raise ColumnNotFoundError


def check_validation_metadata_columns(validation_df):
    """
    Confirm that the validation metadata columns are present
    :param validation_df:
    :return:
    """

    for column_name in METADATA_VALIDATION_COLUMN_NAMES:
        if column_name not in validation_df.columns.tolist():
            logger.error(f"Could not find column {column_name}. "
                         f"The file is not structured as expected! Aborting.")
            raise ColumnNotFoundError
    logger.info(f"Loaded library tracking sheet validation data.")


def remove_blank_rows(lab_metadata_df):
    """
    Remove blank rows from the metadata dataframe
    :param lab_metadata_df:
    :return:
    """

    truncated_lab_metadata_df = lab_metadata_df.query("LibraryID !=''")

    if truncated_lab_metadata_df.shape[0] == 0:
        logger.error("Found no rows of the metadata lab")
        raise ValueError

    return truncated_lab_metadata_df