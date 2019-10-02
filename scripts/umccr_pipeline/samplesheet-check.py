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
lab_spreadsheet_id = '1pZRph8a6-795odibsvhxCqfC6l0hHZzKbGYpesgNXOA'

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
metadata_column_names = (library_id_column_name,
                         subject_id_column_name,
                         sample_id_column_name,
                         sample_name_column_name,
                         project_name_column_name,
                         project_owner_column_name,
                         type_column_name,
                         phenotype_column_name,
                         source_column_name,
                         quality_column_name)

# TODO: retrieve allowed values from metadata sheet
type_values = ['WGS', 'WTS', '10X', 'TSO', 'Exome', 'ctDNA', 'TSO_RNA', 'TSO_DNA', 'other']
phenotype_values = ['normal', 'tumor', 'negative-control']
quality_values = ['Good', 'Poor', 'Borderline']
source_values = ['Blood', 'Cell_line', 'FFPE', 'FNA', 'Organoid', 'RNA', 'Tissue', 'Water', 'Buccal']


# Regex pattern for Sample ID/Name
topup_exp = '(?:_topup\d?)?'
sample_name_int = '(?:PRJ|CCR|MDX)\d{6}'
sample_name_ext = '(_.+)?'
sample_control = '(?:NTC|PTC)'
sample_id_int = 'L\d{7}'
sample_id_ext = 'L' + sample_name_int
regex_sample_id_int = re.compile(sample_id_int + topup_exp)
regex_sample_id_ext = re.compile(sample_id_ext + topup_exp)
regex_sample_name = re.compile(sample_name_int + sample_name_ext + topup_exp)
regex_sample_ctl = re.compile(sample_control + sample_name_ext)


if DEPLOY_ENV == 'prod':
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".log")
else:
    LOG_FILE_NAME = os.path.join(SCRIPT_DIR, SCRIPT + ".dev.log")


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


logger = getLogger()


# method to count the differences between two strings
# NOTE: strings have to be of equal length
def str_compare(a, b):
    cnt = 0
    for i, j in zip(a, b):
        if i != j:
            cnt += 1
    return cnt


def import_library_sheet_from_google(year):
    global library_tracking_spreadsheet_df
    spread = Spread(lab_spreadsheet_id)
    library_tracking_spreadsheet_df = spread.sheet_to_df(sheet='2019', index=0, header_rows=1, start_row=1)
    hit = library_tracking_spreadsheet_df.iloc[0]
    logger.debug(f"First record: {hit}")
    for column_name in metadata_column_names:
        logger.debug(f"Checking for column name {column_name}...")
        if column_name not in hit:
            logger.error(f"Could not find column {column_name}. The file is not structured as expected! Aborting.")
            exit(-1)
    logger.info(f"Loaded {len(library_tracking_spreadsheet_df.index)} records from library tracking sheet.")


def get_meta_data_by_library_id(library_id):
    try:
        global library_tracking_spreadsheet_df
        hit = library_tracking_spreadsheet_df[library_tracking_spreadsheet_df[library_id_column_name] == library_id]
        # We expect exactly one matching record, not more, not less!
        if len(hit) == 1:
            logger.debug(f"Unique entry found for sample ID {library_id}")
        else:
            raise ValueError(f"No unique ({len(hit)}) entry found for sample ID {library_id}")

        return hit
    except Exception as e:
        raise ValueError(f"Could not find entry for sample {library_id}! Exception {e}")
    except (KeyError, NameError, TypeError) as er:
        print(f"Cought Error: {er}")
        # raise


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
        if not (regex_sample_name.fullmatch(sample.Sample_ID) or regex_sample_ctl.fullmatch(sample.Sample_ID)):
            has_error = True
            logger.error(f"Sample_ID '{sample.Sample_ID}' did not match the expected pattern!")
        # check Sample Name against expected format
        if not (regex_sample_id_int.fullmatch(sample.Sample_Name) or regex_sample_id_ext.match(sample.Sample_Name)):
            has_error = True
            logger.error(f"Sample_Name '{sample.Sample_Name}' did not match the expected pattern!")

    return has_error


def checkMetadataCorrespondence(samplesheet):
    logger.info("Checking SampleSheet data against metadata")
    has_error = False

    for sample in samplesheet:
        library_id = sample.Sample_Name  # SampleSheet Sample_Name == LIMS LibraryID
        sample_name = sample.Sample_ID  # SampleSheet Sample_ID == LIMS SampleName
        logger.debug(f"Checking Sammple_ID/Sample_Name: {sample_name}/{library_id}")

        # Make sure the ID exists and is unique
        column_values = get_meta_data_by_library_id(library_id)
        logger.debug(f"Retrieved values: {column_values} for sample {library_id}.")

        # check sample ID/Name match
        if column_values[sample_name_column_name].item() != sample_name:
            logger.warn(f"Sample_ID of SampleSheet ({sample_name}) does not match " +
                        f"SampleID of metadata ({column_values[sample_name_column_name].item()})")

        # exclude 10X samples for now, as they usually don't comply
        if column_values[type_column_name].item() != '10X':
            # check presence of subject ID
            if column_values[subject_id_column_name].item() == '':
                logger.warn(f"No subject ID for {sample_name}")

            # check controlled vocab: phenotype, type, source, quality: WARN if not present
            if column_values[type_column_name].item() not in type_values:
                logger.warn(f"Unsupported Type '{column_values[type_column_name].item()}' for {sample_name}")
            if column_values[phenotype_column_name].item() not in phenotype_values:
                logger.warn(f"Unsupproted Phenotype '{column_values[phenotype_column_name].item()}' for {sample_name}")
            if column_values[quality_column_name].item() not in quality_values:
                logger.warn(f"Unsupproted Quality '{column_values[quality_column_name].item()}'' for {sample_name}")
            if column_values[source_column_name].item() not in source_values:
                logger.warn(f"Unsupproted Source '{column_values[source_column_name].item()}'' for {sample_name}")

            # check project name: WARN if not consistent
            p_name = column_values[project_name_column_name].item()
            p_owner = column_values[project_owner_column_name].item()
            if p_owner != '':
                p_name = p_owner + '_' + p_name
            if p_name != sample.Sample_Project:
                logger.warn(f"Project of SampleSheet ({sample.Sample_Project}) does not match " +
                            f"ProjectName of metadata ({p_name})")

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
    import_library_sheet_from_google('2019')
    # TODO: replace has_error return with enum and expand to error, warning, info?
    has_header_error = checkSampleSheetMetadata(original_sample_sheet)
    has_id_error = checkSampleAndLibraryIdFormat(original_sample_sheet)
    has_index_error = checkSampleSheetForIndexClashes(original_sample_sheet)
    has_metadata_error = checkMetadataCorrespondence(original_sample_sheet)
    # Only fail on metadata or id errors
    if has_header_error or has_id_error or has_index_error or has_metadata_error:
        raise ValueError(f"Validation detected errors. Please review the error logs!")

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
