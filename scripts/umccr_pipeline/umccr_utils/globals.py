#!/usr/bin/env python

"""
GLOBALS used in projects

* METADATA SPREAD SHEET
* SAMPLE SHEET REGEXES
* GOOGLE LIMS
* LOGS
* INSTRUMENTS
* AWS S3


"""

import re

"""
METADATA SPREAD SHEET 
"""

METADATA_COLUMN_NAMES = {  # TODO there more columns than this
  "subject_id": 'SubjectID',  # the internal ID for the subject/patient
  "sample_id": 'SampleID',  # the internal ID for the sample
  "sample_name": 'SampleName',  # the sample name assigned by the lab
  "library_id": 'LibraryID',  # the internal ID for the library
  "project_name": 'ProjectName',
  "project_owner": 'ProjectOwner',
  "type": 'Type',  # the assay type: WGS, WTS, 10X, ...
  "phenotype": 'Phenotype',  # tumor, normal, negative-control, ...
  "override_cycles": "OverrideCycles",  # The Override cycles list for this run
  "source": 'Source',  # tissue, FFPE, ...
  "quality": 'Quality',  # Good, Poor, Borderline
}

METADATA_VALIDATION_COLUMN_NAMES = {
       "val_phenotype": "PhenotypeValues",
       "val_quality": "QualityValues",
       "val_source": "SourceValues",
       "val_type": "TypeValues",
       "val_project_name": "ProjectNameValues",
       "val_project_owner": "ProjectOwnerValues",
}

METADATA_COLUMN_NAMES.update(METADATA_VALIDATION_COLUMN_NAMES)

"""
SAMPLE SHEET DATA COLUMNS
"""

REQUIRED_SAMPLE_SHEET_DATA_COLUMN_NAMES = {
    "v1": ["Lane", "Sample_ID", "Sample_Name", "index"],
    "v2": ["Lane", "Sample_ID", "index"]
}

VALID_SAMPLE_SHEET_DATA_COLUMN_NAMES = {
    # This is the standard
    "v1": ["Lane", "Sample_ID", "Sample_Name", "Sample_Plate", "Sample_Well",
           "Index_Plate_Well", "I7_Index_ID", "index",
           "I5_Index_ID", "index2", "Sample_Project", "Description"],
    # This is the future
    "v2": ["Lane", "Sample_ID", "index", "index2", "Sample_Project"]
}


"""
SAMPLE SHEET REGEXES
"""

EXPERIMENT_REGEX_STR = {
    "top_up": r"(?:_topup\d?)",
    "rerun": r"(?:_rerun\d?)"
}

SAMPLE_ID_REGEX_STR = {
    "sample_id_non_control": r"(?:PRJ|CCR|MDX|TGX)\d{6}",
    "sample_id_control": r"(?:NTC|PTC)_\w+"
}

SAMPLE_ID_REGEX_STR["sample_id"] = r"(?:(?:{})|(?:{}))".format(
    SAMPLE_ID_REGEX_STR["sample_id_non_control"],
    SAMPLE_ID_REGEX_STR["sample_id_control"]
)

LIBRARY_REGEX_STR = {
    "id_int": r"L\d{7}",
    "id_ext": r"L{}".format(SAMPLE_ID_REGEX_STR["sample_id"]),
    "year": r"(?:L|LPRJ)(\d{2})\d+"
}

LIBRARY_REGEX_STR["id"] = r"(?:{}|{})(?:{}|{})?".format(
    LIBRARY_REGEX_STR["id_int"],
    LIBRARY_REGEX_STR["id_ext"],
    EXPERIMENT_REGEX_STR["top_up"],                             # TODO - could a top_up/rerun exist?
    EXPERIMENT_REGEX_STR["rerun"]
)

SAMPLE_REGEX_OBJS = {
    # Sample ID: https://regex101.com/r/Z7fvHt/1
    "sample_id": re.compile(SAMPLE_ID_REGEX_STR["sample_id"]),
    # https://regex101.com/r/Z7fvHt/2
    "library_id": re.compile(LIBRARY_REGEX_STR["id"]),
    # https://regex101.com/r/Yf2t8E/2
    "unique_id_full_match": re.compile("{}_{}".format(SAMPLE_ID_REGEX_STR["sample_id"], LIBRARY_REGEX_STR["id"])),
    # https://regex101.com/r/Yf2t8E/3
    # Use brackets to capture the sample id and the library id
    "unique_id": re.compile("({})_({})".format(SAMPLE_ID_REGEX_STR["sample_id"], LIBRARY_REGEX_STR["id"])),
    # https://regex101.com/r/pkqI1n/1
    "topup": re.compile(EXPERIMENT_REGEX_STR["top_up"]),
    # https://regex101.com/r/nNPwQu/1
    "year": re.compile(LIBRARY_REGEX_STR["year"])
}

SAMPLESHEET_REGEX_STR = {
    "section_header": r"^\[(\S+)\](,+)?"
}

SAMPLESHEET_REGEX_OBJS = {
    # https://regex101.com/r/5nbe9I/1
    "section_header": re.compile(SAMPLESHEET_REGEX_STR["section_header"])
}

OVERRIDE_CYCLES_STR = {
    "cycles": r"(?:([INYU])(\d*))",
    "cycles_full_match": r"(?:[INYU]+(\d*))+"
}

OVERRIDE_CYCLES_OBJS = {
    # https://regex101.com/r/U7bJUI/1
    "cycles": re.compile(OVERRIDE_CYCLES_STR["cycles"]),
    # https://regex101.com/r/U7bJUI/2
    "cycles_full_match": re.compile(OVERRIDE_CYCLES_STR["cycles_full_match"])
}

"""
GOOGLE LIMS
"""

LAB_SPREAD_SHEET_ID = {
    "dev": "1Pgz13btHOJePiImo-NceA8oJKiQBbkWI5D2dLdKpPiY",
    "prod": "1pZRph8a6-795odibsvhxCqfC6l0hHZzKbGYpesgNXOA"
}

LIMS_SPREAD_SHEET_ID = {
    "dev": '1vX89Km1D8dm12aTl_552GMVPwOkEHo6sdf1zgI6Rq0g',
    "prod": '1aaTvXrZSdA1ekiLEpW60OeNq2V7D_oEMBzTgC-uDJAM'
}

LIMS_COLUMNS = {  # Columns in order!
  "illumina_id": 'IlluminaID',
  "run": 'Run',
  "timestamp": 'Timestamp',
  "subject_id": 'SubjectID',  # the internal ID for the subject/patient
  "sample_id": 'SampleID',  # the internal ID for the sample
  "library_id": 'LibraryID',  # the internal ID for the library
  "subject_ext_id": 'ExternalSubjectID',  # the external (provided) ID for the subject/patient
  "sample_ext_id": 'ExternalSampleID',  # is the external (provided) sample ID
  "library_ext_id": 'ExternalLibraryID',  # is the external (provided) library ID
  "sample_name": 'SampleName',  # the sample name assigned by the lab
  "project_owner": 'ProjectOwner',
  "project_name": 'ProjectName',
  "project_custodian": 'ProjectCustodian',
  "type": 'Type',  # the assay type: WGS, WTS, 10X, ...
  "assay": 'Assay',
  "override_cycles": 'OverrideCycles',
  "phenotype": 'Phenotype',  # tomor, normal, negative-control, ...
  "source": 'Source',  # tissue, FFPE, ...
  "quality": 'Quality',  # Good, Poor, Borderline
  "topup": 'Topup',
  "secondary_analysis": 'SecondaryAnalysis',
  "workflow": 'Workflow',
  "tags": 'Tags',
  "fastq": 'FASTQ',
  "number_fastqs": 'NumberFASTQS',
  "results": 'Results',
  "trello": 'Trello',
  "notes": 'Notes',
  "todo": 'ToDo',
}

"""
LOGS
"""

LOG_FILE_NAME = {}  # TODO - path to samplesheet-check-script.py . dirname + .dev.log" or + ".prod.log"
                    # TODO - also needs to be set on the log file

"""
INSTRUMENTS
"""

INSTRUMENT_NAMES = {
    "A01052": "Po",
    "A00130": "Baymax"
}


"""
AWS S3
"""
FASTQ_S3_BUCKET = {
    "prod": 's3://umccr-fastq-data-prod/'
}

