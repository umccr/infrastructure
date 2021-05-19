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

METADATA_COLUMN_NAMES = {
  "library_id": 'LibraryID',  # the internal ID for the library
  "sample_name": 'SampleName',  # the sample name assigned by the lab
  "sample_id": 'SampleID',  # the internal ID for the sample
  "external_sample_id": 'ExternalSampleID',  # the external ID for the sample
  "subject_id": 'SubjectID',  # the internal ID for the subject/patient
  "external_subject_id": "ExternalSubjectID",  # The external subject ID
  "phenotype": 'Phenotype',  # tumor, normal, negative-control, ...
  "quality": 'Quality',  # Good, Poor, Borderline
  "source": 'Source',  # tissue, FFPE, ...
  "project_name": 'ProjectName',
  "project_owner": 'ProjectOwner',
  "experiment_id": "ExperimentID",
  "type": 'Type',  # the sample type: WGS, WTS, 10X, ...
  "assay": "Assay",  # the assay type; TsqNano, NebRNA ...
  "override_cycles": "OverrideCycles",  # The Override cycles list for this run
  "secondary_analysis": "Workflow",  # ?
  "coverage": "Coverage (X)",  # ?
  "truseq_index": "TruSeq Index, unless stated",  # FIXME - this is a terrible column name
  "run": "Run#",
  "comments": "Comments",
  "rrna": "rRNA",
  "qpc_id": "qPCR ID",
  "sample_id_samplesheet": "Sample_ID (SampleSheet)"  # FIXME - this is named 'Sample_ID (SampleSheet)' in the dev spreadsheet
}


"""
METADATA SPREAD SHEET 
"""

METADATA_VALIDATION_COLUMN_NAMES = {
       "val_phenotype": "PhenotypeValues",
       "val_quality": "QualityValues",
       "val_source": "SourceValues",
       "val_type": "TypeValues",
       "val_project_name": "ProjectNameValues",
       "val_project_owner": "ProjectOwnerValues",
}

#METADATA_COLUMN_NAMES.update(METADATA_VALIDATION_COLUMN_NAMES)

"""
SAMPLE SHEET DATA COLUMNS
"""

REQUIRED_SAMPLE_SHEET_DATA_COLUMN_NAMES = {
    "v1": ["Sample_ID", "Sample_Name", "index"],
    "v2": ["Sample_ID", "index"]
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
    "cycles_full_match": r"(?:[INYU]+(\d*))+",
    "indexes": r"((?:[I])(\d*))"
}

OVERRIDE_CYCLES_OBJS = {
    # https://regex101.com/r/U7bJUI/1
    "cycles": re.compile(OVERRIDE_CYCLES_STR["cycles"]),
    # https://regex101.com/r/U7bJUI/2
    "cycles_full_match": re.compile(OVERRIDE_CYCLES_STR["cycles_full_match"]),
    "indexes": re.compile(OVERRIDE_CYCLES_STR["indexes"])
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

LIMS_SPREAD_SHEET_NAMES = {
    "SHEET_NAME_RUNS": "Sheet1",
    "SHEET_NAME_FAILED": "Failed Runs"
}

LIMS_COLUMNS = {  # Columns in order!
  "illumina_id": 'IlluminaID',
  "run": 'Run',
  "timestamp": 'Timestamp',
  "subject_id": 'SubjectID',  # the internal ID for the subject/patient
  "sample_id": 'SampleID',  # the internal ID for the sample
  "library_id": 'LibraryID',  # the internal ID for the library
  "external_subject_id": 'ExternalSubjectID',  # the external (provided) ID for the subject/patient
  "external_sample_id": 'ExternalSampleID',  # is the external (provided) sample ID
  "external_library_id": 'ExternalLibraryID',  # is the external (provided) library ID
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

LOG_FILE_SUFFIX = {
    "dev": "dev.log",
    "prod": "prod.log"
}

LOGGER_STYLE = "%(asctime)s - %(levelname)-8s - %(module)-25s - %(funcName)-40s : LineNo. %(lineno)-4d - %(message)s"

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

"""
NOVASTOR PATHS
"""

NOVASTOR_RAW_BCL_DIR = {
    "prod": "/storage/shared/raw",
    "dev": "/storage/shared/dev"
}

NOVASTOR_FASTQ_OUTPUT_DIR = {
    "prod": "/storage/shared/bcl2fastq_output",
    "dev": "/storage/shared/dev/bcl2fastq_output"
}

NOVASTOR_CRED_PATHS = {
    "google_write_token": "/home/limsadmin/.google/google-lims-updater-b50921f70155.json"
}

NOVASTOR_CSV_DIR = "/tmp"

"""
RUN NAME REGEXES

A run comprises

<YYMMDD>_<MACHINE_ID>_<RUN_ID>_<SLOT><FLOWCELL_ID>
"""

# Taken from
# https://regexlib.com/REDetails.aspx?regexp_id=326
# Test seen here
# https://regex101.com/r/TCSmm5/3
DATE_STR = r"(?:(?:\d{2}(?:(?:0[13578]|1[02])(?:0[1-9]|[12]\d|3[01])|(?:0[13456789]|1[012])" \
           r"(?:0[1-9]|[12]\d|30)|02(?:0[1-9]|1\d|2[0-8])))|(?:[02468][048]|[13579][26])0229)"


# https://regex101.com/r/2iCeNg/1
MACHINE_STR = r"(?:{})".format("|".join(list(INSTRUMENT_NAMES.keys())))

# RUN_STR
RUNID_STR = r"(?:\d{4})"  # Four digit int

SLOT_STR = r"(?:A|B)"

# From
# https://support.illumina.com/help/BaseSpace_ClarityLIMS_OLH_115205/Content/Source/ClarityLIMS/Integrations/ConfigurationUpdateRequiredforNovaSeqFlowcellBarcodeSuffixChange.htm
FLOWCELL_REGEX_STR = {
    "SP": r"\w{5}DRX[XY2357]",
    "S1": r"\w{5}DRX[XY2357]",
    "S2": r"\w{5}DMX[XY2357]",
    "S4": r"\w{5}DSX[XY2357]"
}

# https://regex101.com/r/2gdY7O/1
FLOWCELL_REGEX_STR["all"] = r'(?:{})'.format("|".join(list(FLOWCELL_REGEX_STR.values())))

# Now combine all into a perfect - easy-to-read - capturing regex
RUN_REGEX_OBJS = {
    # https://regex101.com/r/AYy9es/1
    "run": re.compile(r"({})_({})_({})_({})({})".format(
        DATE_STR, MACHINE_STR, RUNID_STR, SLOT_STR, FLOWCELL_REGEX_STR['all']
    )),
    # https://regex101.com/r/gBd5gx/1
    "run_fullmatch": re.compile(r"{}_{}_{}_{}{}".format(
        DATE_STR, MACHINE_STR, RUNID_STR, SLOT_STR, FLOWCELL_REGEX_STR['all']
    ))
}

"""
GOOGLE ACCOUNT
"""

GSERVICE_ACCOUNT = "data-portal@umccr-portal.iam.gserviceaccount.com"


"""
INDEX DISTANCES
"""

MIN_INDEX_HAMMING_DISTANCE = 3
