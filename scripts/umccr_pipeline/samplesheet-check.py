import sys
import os
import re
import argparse
import logging
from logging.handlers import RotatingFileHandler
import collections
from sample_sheet import SampleSheet  # https://github.com/clintval/sample-sheet
from gspread_pandas import Spread


import warnings
warnings.simplefilter("ignore")

DEPLOY_ENV = os.getenv('DEPLOY_ENV')
SCRIPT = os.path.basename(__file__)
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

subject_id_column_name = 'SubjectID'  # the internal ID for the subject/patient
sample_id_column_name = 'SampleID'  # the internal ID for the sample
sample_name_column_name = 'SampleName'  # the sample name assigned by the lab
library_id_column_name = 'LibraryID'  # the internal ID for the library
project_name_column_name = 'ProjectName'
project_owner_column_name = 'ProjectOwner'
type_column_name = 'Type'  # the assay type: WGS, WTS, 10X, ...
phenotype_column_name = 'Phenotype'  # tomor, normal, negative-control, ...
source_column_name = 'Source'  # tissue, FFPE, ...
quality_column_name = 'Quality'  # Good, Poor, Borderline
# List of column names expected to be found in the tracking sheet
metadata_column_names = (
    library_id_column_name,
    subject_id_column_name,
    sample_id_column_name,
    sample_name_column_name,
    project_name_column_name,
    project_owner_column_name,
    type_column_name,
    phenotype_column_name,
    source_column_name,
    quality_column_name)
val_phenotype_column_name = "PhenotypeValues"
val_quality_column_name = "QualityValues"
val_source_column_name = "SourceValues"
val_type_column_name = "TypeValues"
val_project_name_column_name = "ProjectNameValues"
val_project_owner_column_name = "ProjectOwnerValues"
# List of column names expected to be found in the validation sheet (i.e. named ranges for allowed values)
metadata_validation_column_names = (
    val_phenotype_column_name,
    val_quality_column_name,
    val_source_column_name,
    val_type_column_name,
    val_project_name_column_name,
    val_project_owner_column_name)

# Regex pattern for Sample ID/Name
topup_exp = '(?:_topup\d?)'
rerun_exp = '(?:_rerun\d?)'
sample_id = '(?:PRJ|CCR|MDX|TGX)\d{6}'
sample_control = '(?:NTC|PTC)_\w+'
library_id_int = 'L\d{7}'
library_id_ext = 'L' + sample_id
library_id = '(?:' + library_id_int + '|' + library_id_ext + ')(?:' + topup_exp + '|' + rerun_exp + ')?'

regex_sample_id = re.compile(sample_id + '_' + library_id)
regex_sample_id_ctl = re.compile(sample_control + library_id)
regex_sample_name = re.compile(library_id)
regex_topup = re.compile(topup_exp)


if DEPLOY_ENV == 'dev':
    print("DEV")
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".dev.log")
    lab_spreadsheet_id = '1Pgz13btHOJePiImo-NceA8oJKiQBbkWI5D2dLdKpPiY'  # Lab metadata tracking sheet (dev)
else:
    print("PROD")
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
    lab_spreadsheet_id = '1pZRph8a6-795odibsvhxCqfC6l0hHZzKbGYpesgNXOA'  # Lab metadata tracking sheet (prod)


def getLogger():
    new_logger = logging.getLogger(__name__)
    new_logger.setLevel(logging.DEBUG)

    # create a logging format
    formatter = logging.Formatter('%(asctime)s - %(module)s - %(name)s - %(levelname)s : %(lineno)d - %(message)s')

    # create a file handler
    file_handler = RotatingFileHandler(filename=LOG_FILE_NAME, maxBytes=100000000, backupCount=5)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)

    # create a console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.WARNING)
    console_handler.setFormatter(formatter)

    # add the handlers to the logger
    new_logger.addHandler(file_handler)
    new_logger.addHandler(console_handler)

    return new_logger


# method to count the differences between two strings
# NOTE: strings have to be of equal length
def str_compare(a, b):
    cnt = 0
    for i, j in zip(a, b):
        if i != j:
            cnt += 1
    return cnt


def get_year_from_lib_id(library_id):
    # TODO: check library ID format and make sure we have proper years
    if library_id.startswith('LPRJ'):
        return '20' + library_id[4:6]
    else:
        return '20' + library_id[1:3]


def get_years_from_samplesheet(samplesheet):
    years = set()
    for sample in samplesheet:
        years.add(get_year_from_lib_id(sample.Sample_Name))
    return years


def get_library_sheet_from_google(year):
    logger.info(f"Loading tracking data for year {year}")
    spread = Spread(lab_spreadsheet_id)
    library_tracking_spreadsheet_df = spread.sheet_to_df(sheet=year, index=0, header_rows=1, start_row=1)
    hit = library_tracking_spreadsheet_df.iloc[0]
    logger.debug(f"First record: {hit}")
    for column_name in metadata_column_names:
        logger.debug(f"Checking for column name {column_name}...")
        if column_name not in hit:
            logger.error(f"Could not find column {column_name}. The file is not structured as expected! Aborting.")
            exit(-1)
    logger.info(f"Loaded {len(library_tracking_spreadsheet_df.index)} records from library tracking sheet.")
    return library_tracking_spreadsheet_df


def import_library_sheet_validation_from_google():
    global validation_df
    spread = Spread(lab_spreadsheet_id)
    validation_df = spread.sheet_to_df(sheet='Validation', index=0, header_rows=1, start_row=1)
    hit = validation_df.iloc[0]
    logger.debug(f"First record of validation data: {hit}")
    for column_name in metadata_validation_column_names:
        logger.debug(f"Checking for column name {column_name}...")
        if column_name not in hit:
            logger.error(f"Could not find column {column_name}. The file is not structured as expected! Aborting.")
            exit(-1)
    logger.info(f"Loaded library tracking sheet validation data.")


def get_meta_data_by_library_id(library_id):
    year = get_year_from_lib_id(library_id)
    library_tracking_spreadsheet_df = library_tracking_spreadsheet.get(year)
    try:
        hit = library_tracking_spreadsheet_df[library_tracking_spreadsheet_df[library_id_column_name] == library_id]
    except (KeyError, NameError, TypeError, Exception) as er:
        logger.error(f"Error trying to find library ID {library_id}! Error: {er}")

    # We expect exactly one matching record, not more, not less!
    if len(hit) == 1:
        logger.debug(f"Unique entry found for sample ID {library_id}")
    elif len(hit) > 1:
        logger.error(f"Multiple entries for library ID {library_id}!")
    else:
        logger.error(f"No entry for library ID {library_id}")
    return hit


def checkSampleSheetMetadata(samplesheet):
    logger.info("Checking SampleSheet metadata")
    has_error = False
    if not samplesheet.Header.Assay:
        has_error = True
        logger.error("Assay not defined in Header!")
    if not samplesheet.Header.get('Experiment Name'):
        has_error = True
        logger.error("Experiment Name not defined in Header!")

    return has_error


def checkSampleAndLibraryIdFormat(samplesheet):
    logger.info("Checking SampleSheet data records")
    has_error = False

    for sample in samplesheet:
        logger.debug(f"Checking Sammple_ID/Sample_Name: {sample.Sample_ID}/{sample.Sample_Name}")
        # Checkt that the IDs are not the same
        if sample.Sample_ID == sample.Sample_Name:
            has_error = True
            logger.error(f"Sample_ID '{sample.Sample_ID}' cannot be the same as the Sample_Name!")
        # check Sample ID against expected format
        if not (regex_sample_id.fullmatch(sample.Sample_ID) or regex_sample_id_ctl.fullmatch(sample.Sample_ID)):
            has_error = True
            logger.error(f"Sample_ID '{sample.Sample_ID}' did not match the expected pattern!")
        # check Sample Name against expected format
        if not regex_sample_name.fullmatch(sample.Sample_Name):
            has_error = True
            logger.error(f"Sample_Name '{sample.Sample_Name}' did not match the expected pattern!")

    return has_error


def checkMetadataCorrespondence(samplesheet):
    logger.info("Checking SampleSheet data against metadata")
    has_error = False
    global validation_df

    for sample in samplesheet:
        ss_sample_name = sample.Sample_Name  # SampleSheet Sample_Name == LIMS LibraryID
        ss_sample_id = sample.Sample_ID  # SampleSheet Sample_ID == LIMS SampleID_LibraryID
        logger.debug(f"Checking Sammple_ID/Sample_Name: {ss_sample_id}/{ss_sample_name}")

        # Make sure the ID exists and is unique
        column_values = get_meta_data_by_library_id(ss_sample_name)
        if len(column_values) != 1:
            has_error = False
            continue
        logger.debug(f"Retrieved values: {column_values} for sample {ss_sample_name}.")

        # check sample ID/Name match
        ss_sn = column_values[sample_id_column_name].item() + '_' + column_values[library_id_column_name].item()
        if ss_sn != ss_sample_id:
            has_error = True
            logger.error(f"Sample_ID of SampleSheet ({ss_sample_id}) does not match " +
                         f"SampleID/LibraryID of metadata ({ss_sn})")

        # exclude 10X samples for now, as they usually don't comply
        if column_values[type_column_name].item() != '10X':
            # check presence of subject ID
            if column_values[subject_id_column_name].item() == '':
                logger.warn(f"No subject ID for {ss_sample_id}")

            # check controlled vocab: phenotype, type, source, quality: WARN if not present
            if column_values[type_column_name].item() not in validation_df[val_type_column_name].values:
                logger.warn(f"Unsupported Type '{column_values[type_column_name].item()}' for {ss_sample_id}")
            if column_values[phenotype_column_name].item() not in validation_df[val_phenotype_column_name].values:
                logger.warn(f"Unsupproted Phenotype '{column_values[phenotype_column_name].item()}' for {ss_sample_id}")
            if column_values[quality_column_name].item() not in validation_df[val_quality_column_name].values:
                logger.warn(f"Unsupproted Quality '{column_values[quality_column_name].item()}' for {ss_sample_id}")
            if column_values[source_column_name].item() not in validation_df[val_source_column_name].values:
                logger.warn(f"Unsupproted Source '{column_values[source_column_name].item()}' for {ss_sample_id}")

            # check project name: WARN if not consistent
            p_name = column_values[project_name_column_name].item()
            p_owner = column_values[project_owner_column_name].item()
            if p_owner == '':
                has_error = True
                logger.error(f"No project owner found for sample {sample.Sample_ID}")
            if len(validation_df[validation_df[val_project_owner_column_name] == p_owner]) != 1:
                has_error = True
                logger.error(f"Project owner {p_owner} not found in allowed values!")
            if p_name == '':
                has_error = True
                logger.error(f"No project name found for sample {sample.Sample_ID}")
            if len(validation_df[validation_df[val_project_name_column_name] == p_name]) != 1:
                has_error = True
                logger.error(f"Project name {p_name} not found in allowed values!")

        # check that the primary library for the topup exists
        if regex_topup.search(sample.Sample_Name):
            orig_library_id = regex_topup.sub('', sample.Sample_Name)
            if len(get_meta_data_by_library_id(orig_library_id)) != 1:
                logger.error(f"Couldn't find library {orig_library_id} for topup {sample.Sample_Name}")
                has_error = True

    return has_error


def checkSampleSheetForIndexClashes(samplesheet):
    logger.info("Checking SampleSheet for index clashes")
    has_error = False

    remaining_samples = list()
    for sample in samplesheet:
        remaining_samples.append(sample)

    for sample in samplesheet:
        remaining_samples.remove(sample)
        logger.info(f"Comparing indexes of sample {sample}")
        sample_i7 = sample.index.replace('N', '')
        sample_i5 = sample.index2.replace('N', '')
        # compare i7 to i5 of sample
        if len(sample_i5) > 0:
            if len(sample_i7) == len(sample_i5):
                if str_compare(sample_i7, sample_i5) <= 1:
                    logger.error(f"Too similar: i7 and i5 for sample {sample}")
                    has_error = True
            else:
                if sample_i5 in sample_i7:
                    logger.error(f"Substring: i5 of i7 for sample {sample}")
                    has_error = True
        else:
            logger.debug(f"Skipping i5 index of sample {sample}")
        for sample_other in remaining_samples:
            logger.info(f"Checking indexes of sample {sample} against {sample_other}")
            if sample.Sample_ID != sample_other.Sample_ID and sample.lane == sample_other.lane:
                sample_other_i7 = sample_other.index.replace('N', '')
                sample_other_i5 = sample_other.index2.replace('N', '')
                # compare i7 of sample to i7 of other sample
                if len(sample_i7) == len(sample_other_i7):
                    if str_compare(sample_i7, sample_other_i7) <= 1:
                        logger.error(f"Too similar: i7 for samples {sample} and {sample_other}")
                        has_error = True
                else:
                    if sample_other_i7 in sample_i7 or sample_i7 in sample_other_i7:
                        logger.error(f"Substring: i7 for samples {sample} and {sample_other}")
                        has_error = True
                # compare i7 of sample to i5 of other sample
                if len(sample_i7) == len(sample_other_i5):
                    if str_compare(sample_i7, sample_other_i5) <= 1:
                        logger.error(f"Too similar: i7/i5 for samples {sample} and {sample_other}")
                        has_error = True
                elif len(sample_other_i5) > 0:
                    if sample_other_i5 in sample_i7 or sample_i7 in sample_other_i5:
                        logger.error(f"Substring: i5/i7 for samples {sample} and {sample_other}")
                        has_error = True
                else:
                    logger.info(f"Skipping i5 index of sample {sample_other}")
                # compare i5 of sample to i7 of other sample
                if len(sample_i5) == len(sample_other_i7):
                    if str_compare(sample_i5, sample_other_i7) <= 1:
                        logger.error(f"Too similar: i5/i7 for samples {sample} and {sample_other}")
                        has_error = True
                elif len(sample_i5) > 0:
                    if sample_i5 in sample_other_i7 or sample_other_i7 in sample_i5:
                        logger.error(f"Substring: i5/i7 for samples {sample} and {sample_other}")
                        has_error = True
                else:
                    logger.info(f"Skipping i5 index of sample {sample}")
                # compare i5 of sample to i5 of other sample
                if len(sample_i5) > 0:
                    if len(sample_i5) == len(sample_other_i5):
                        if str_compare(sample_i5, sample_other_i5) <= 1:
                            logger.error(f"Too similar: i5/i5 for samples {sample} and {sample_other}")
                            has_error = True
                    elif len(sample_other_i5) > 0:
                        if sample_i5 in sample_other_i5 or sample_other_i5 in sample_i5:
                            logger.error(f"Substring: i5/i5 for samples {sample} and {sample_other}")
                            has_error = True
                    else:
                        logger.info(f"Skipping i5 index of sample {sample_other}")
                else:
                    logger.info(f"Skipping i5 index of sample {sample}")
            else:
                logger.info(f"Sample sample or different lane")

    return has_error


def getSortedSamples(samplesheet):
    sorted_samples = collections.defaultdict(list)
    for sample in samplesheet:
        # replace N index with ""
        sample.index = sample.index.replace("N", "")
        index_length = len(sample.index)

        if sample.index2:
            sample.index2 = sample.index2.replace("N", "")
            index2_length = len(sample.index2)
            # make sure to remove the index ID if there is no index sequence
            if index2_length is 0:
                sample.I5_Index_ID = ""
        else:
            index2_length = 0

        if sample.I7_Index_ID.startswith("SI-GA"):
            sorted_samples[("10X", index_length, index2_length)].append(sample)
            logger.debug(f"Adding sample {sample} to key (10X, {index_length}, {index2_length})")
        else:
            sorted_samples[("truseq", index_length, index2_length)].append(sample)
            logger.debug(f"Adding sample {sample} to key (truseq, {index_length}, {index2_length})")

    return sorted_samples


def writeSammpleSheets(sample_list, sheet_path, template_sheet):
    samplesheet_name = os.path.basename(sheet_path)
    samplesheet_dir = os.path.dirname(os.path.realpath(sheet_path))
    count = 0
    exit_status = "success"
    for key in sample_list:
        count += 1
        logger.debug(f"{len(sample_list[key])} samples with idx lengths {key[1]}/{key[2]} for {key[0]} dataset")

        new_sample_sheet = SampleSheet()
        new_sample_sheet.Header = template_sheet.Header
        new_sample_sheet.Reads = template_sheet.Reads
        new_sample_sheet.Settings = template_sheet.Settings
        for sample in sample_list[key]:
            new_sample_sheet.add_sample(sample)

        new_sample_sheet_file = os.path.join(samplesheet_dir, samplesheet_name + ".custom." + str(count) + "." + key[0])
        logger.info(f"Creating custom sample sheet: {new_sample_sheet_file}")
        try:
            with open(new_sample_sheet_file, "w") as ss_writer:
                new_sample_sheet.write(ss_writer)
        except Exception as error:
            logger.error(f"Exception writing new sample sheet: {error}")
            exit_status = "failure"

        logger.debug(f"Created custom sample sheet: {new_sample_sheet_file}")

    return exit_status


def main(samplesheet_file_path, check_only):
    logger.info(f"Checking SampleSheet {samplesheet_file_path}")
    original_sample_sheet = SampleSheet(samplesheet_file_path)

    # Run some consistency checks
    years = get_years_from_samplesheet(original_sample_sheet)
    logger.info(f"Samplesheet contains IDs from {len(years)} years: {years}")
    for year in years:
        library_tracking_spreadsheet[year] = get_library_sheet_from_google(year)
    import_library_sheet_validation_from_google()
    # TODO: replace has_error return with enum and expand to error, warning, info?
    has_header_error = checkSampleSheetMetadata(original_sample_sheet)
    has_id_error = checkSampleAndLibraryIdFormat(original_sample_sheet)
    has_index_error = checkSampleSheetForIndexClashes(original_sample_sheet)
    has_metadata_error = checkMetadataCorrespondence(original_sample_sheet)
    # Only fail on metadata or id errors
    if has_index_error:
        print("Index errors detected. Note: the pipeline will ignore those, please make sure to review those errors!")
    if has_header_error or has_id_error or has_metadata_error:
        raise ValueError("Pipeline breaking validation detected errors. Please review the error logs!")

    # Split and write individual SampleSheets, based on indexes and technology (10X)
    if not check_only:
        # Sort samples based on technology (truseq/10X and/or index length)
        # Also replace N indexes with ""
        sorted_samples = getSortedSamples(original_sample_sheet)

        # Now that the samples have been sorted, we can write one or more custom sample sheets
        # (which may be the same as the original if no processing was necessary)
        logger.info(f"Writing {len(sorted_samples)} sample sheets.")
        writeSammpleSheets(sample_list=sorted_samples,
                           sheet_path=samplesheet_file_path,
                           template_sheet=original_sample_sheet)

    logger.info("All done.")


# global variables
# TODO: should be refactored in proper class variables
library_tracking_spreadsheet = dict()  # dict of sheets as dataframes
logger = getLogger()

if __name__ == "__main__":
    logger.info(f"Invocation with parameters: {sys.argv[1:]}")

    if DEPLOY_ENV == "prod":
        logger.info("Running script in prod mode.")
    elif DEPLOY_ENV == "dev":
        logger.info("Running script in dev mode.")
    else:
        print("DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'.")
        exit(1)

    ################################################################################
    # argument parsing

    logger.debug("Setting up argument parser.")
    parser = argparse.ArgumentParser(description='Generate data for LIMS spreadsheet.')
    parser.add_argument('samplesheet',
                        help="The samplesheet to process.")
    parser.add_argument('--check-only', action='store_true',
                        help="Only run the checks, do not split the samplesheet.")

    logger.debug("Parsing arguments.")
    args = parser.parse_args()
    samplesheet_file_path = args.samplesheet
    check_only = True if args.check_only else False

    main(samplesheet_file_path=samplesheet_file_path, check_only=check_only)
