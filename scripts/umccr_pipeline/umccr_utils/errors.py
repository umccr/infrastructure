#!/usr/bin/env python
"""
ERRORS
"""


class ColumnNotFoundError(Exception):
    """
    The Column of the dataframe or excel spread sheet is not found
    """
    pass


class LibraryNotFoundError(Exception):
    """
    We could not find the library ID in the metadata spreadsheet
    """
    pass


class MultipleLibraryError(Exception):
    """
    We found more than one library corresponding to this sample in the metadata sheet
    """
    pass


class GetMetaDataError(Exception):
    """
    A collective error for LibraryNotFoundError and MultipleLibraryError
    We failed to collect the requested metadata
    """
    pass


class SampleSheetFormatError(Exception):
    """
    Config-like construction was not found
    """
    pass


class SampleSheetHeaderError(Exception):
    """
    We failed to collect an attribute in the SampleSheet header
    """
    pass


class SampleNotFoundError(Exception):
    """
    We failed to find a sample sheet in the sample sheet with this ID
    """
    pass


class SampleDuplicateError(Exception):
    """
    Sample with the same id already exists in the sample sheet
    """


class SampleNameFormatError(Exception):
    """
    The sample sheet was not in the correct format
    """
    pass


class SimilarIndexError(Exception):
    """
    Two indexes of separate samples were too similar
    """
    pass


class MetaDataError(Exception):
    """
    Wrapper error for GetMetaDataError and LibraryNotFound, ColumnNotFound
    """
    pass


class OverrideCyclesError(Exception):
    """
    Wrapper error - a samples' override cycle section in the metadata sheet wasn't correct
    """
    pass


class InvalidColumnError(Exception):
    """
    This column is not recognised
    """
    pass