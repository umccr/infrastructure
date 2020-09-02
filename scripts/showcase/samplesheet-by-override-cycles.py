#!/usr/bin/env python3

"""
Take in a samplesheet,
Look through headers, rename as necessary
Look through samples, update override cycles logic as necessary
Split samplesheet out into separate override cycles files
Write to separate files
"""

# Imports
import re
import os
import pandas as pd
import logging
import argparse
from pathlib import Path
import sys

# Set logging level
logging.basicConfig(level=logging.DEBUG)

"""
Read:
config = configparser.RawConfigParser()
config.read('example.cfg')

Write
with open('example.ini', 'w') as configfile:
...   config.write(configfile)
"""

# Globals
SAMPLESHEET_HEADER_REGEX = r"^\[(\S+)\](,+)?"  # https://regex101.com/r/5nbe9I/1
V2_SAMPLESHEET_HEADER_VALUES = {"Data": "BCLConvert_Data",
                                "Settings": "BCLConvert_Settings"}


def get_args():
    """
    Get arguments for the command
    """
    parser = argparse.ArgumentParser(description="Create samplesheets based on override cycles inputs."
                                                 "Expects a v1 samplesheet as input and overridecycles and samples"
                                                 "as inputs through comma-separated arrays")

    # Arguments
    parser.add_argument("--samplesheet-csv", required=True,
                        help="Path to samplesheet csv")
    parser.add_argument("--out-dir", required=False,
                        help="Output directory for samplesheets, set to cwd if not specified")
    parser.add_argument("--samples", required=False,
                        help="Comma separated values to match override-cycles arg")
    parser.add_argument("--override-cycles", required=False,
                        help="Comma separated values to match samples arg")
    parser.add_argument("--ignore-missing-samples", required=False,
                        default=False, action="store_true",
                        help="Truncate samplesheet to only those samples in the --samples arg,"
                             "If not set, error if samples in the samplesheet are not present in --samples arg")
    parser.add_argument("--v2", required=False,
                        default=False, action="store_true",
                        help="Do we wish to output a V2 samplesheet - changes heading names")

    return parser.parse_args()


def read_samplesheet_csv(samplesheet_csv_path):
    """
    Read the samplesheet like a dodgy INI parser
    :param samplesheet_csv_path:
    :return:
    """
    with open(samplesheet_csv_path, "r") as samplesheet_csv_h:
        # Read samplesheet in
        sample_sheet_sections = {}
        current_section = None
        current_section_item_list = []
        header_match_regex = re.compile(SAMPLESHEET_HEADER_REGEX)

        for line in samplesheet_csv_h.readlines():
            # Check if blank line
            if line.strip().rstrip(",") == "":
                continue
            # Check if the current line is a header
            header_match_obj = header_match_regex.match(line.strip())
            if header_match_obj is not None and current_section is None:
                # First line, don't need to write out previous section to obj
                # Set current section to first group
                current_section = header_match_obj.group(1)
                current_section_item_list = []
            elif header_match_obj is not None and current_section is not None:
                # A header further down, write out previous section and then reset sections
                sample_sheet_sections[current_section] = current_section_item_list
                # Now reset sections
                current_section = header_match_obj.group(1)
                current_section_item_list = []
            # Make sure the first line is a section
            elif current_section is None and header_match_obj is None:
                logging.error("Top line of csv was not a section header. Exiting")
                sys.exit(1)
            else:  # We're in a section
                if not current_section == "Data":
                    # Strip trailing slashes from line
                    current_section_item_list.append(line.strip().rstrip(","))
                else:
                    # Don't strip trailing slashes from line
                    current_section_item_list.append(line.strip())

        # Write out the last section
        sample_sheet_sections[current_section] = current_section_item_list

        return sample_sheet_sections


def configure_samplesheet_obj(sample_sheet_obj):
    """
    Each section of the samplesheet obj is in a ',' delimiter ini format
    Except for [Reads] which is just a list
    And [Data] which is a dataframe
    :param sample_sheet_obj:
    :return:
    """

    for section_name, section_str_list in sample_sheet_obj.items():
        if section_name == "Data":
            # Convert to dataframe
            sample_sheet_obj[section_name] = pd.DataFrame(columns=section_str_list[0].split(","),
                                                          data=[row.split(",") for row in
                                                                section_str_list[1:]])
        elif section_name == "Reads":
            # Keep as a list
            continue
        else:
            # Convert to dict
            sample_sheet_obj[section_name] = {line.split(",", 1)[0]: line.split(",", 1)[-1]
                                              for line in section_str_list}

    return sample_sheet_obj


def set_args(args):
    """
    Convert --samples and--override-cycles to arrays
    Check they're the same length
    :return:
    """

    # Get user args
    samplesheet_csv_arg = getattr(args, "samplesheet_csv", None)
    outdir_arg = getattr(args, "out_dir", None)
    samples_arg = getattr(args, "samples", None)
    override_cycles_arg = getattr(args, "override_cycles", None)

    # Convert samplesheet csv to path
    samplesheet_csv_path = Path(samplesheet_csv_arg)
    # Check its a file
    if not samplesheet_csv_path.is_file():
        logging.error("Could not find file {}".format(samplesheet_csv_path))
        sys.exit(1)
    # Set attribute as Path object
    setattr(args, "samplesheet_csv", samplesheet_csv_path)

    # Checking the output path
    if outdir_arg is None:
        outdir_arg = os.getcwd()
    outdir_path = Path(outdir_arg)
    if not outdir_path.parent.is_dir():
        logging.error("Could not create --out-dir, make sure parents exist. Exiting")
        sys.exit(1)
    elif not outdir_path.is_dir():
        outdir_path.mkdir(parents=False)
    setattr(args, "out_dir", outdir_path)

    # Check either both or neither are None
    if not bool(samples_arg is None) == bool(override_cycles_arg is None):
        logging.error("Must specify both --samples and --override-cycles or neither")
        sys.exit(1)

    # Nothing to do if they're both none
    if samples_arg is None and override_cycles_arg is None:
        return args

    # Convert to arrays
    samples_list = samples_arg.split(",")
    override_cycles_list = override_cycles_arg.split(",")

    # Check lengths are the same
    if not len(samples_list) == len(override_cycles_list):
        logging.error("Found unequal number of entries for samples and override cycles")

    # Set attr as lists
    setattr(args, "samples", samples_list)
    setattr(args, "override_cycles", override_cycles_list)

    # Return args
    return args


def merge_samples_and_override_cycles_array_to_df(samples_list, override_cycles_list):
    """
    Convert to dataframe and return
    :param samples_list:
    :param override_cycles_list:
    :return:
    """

    return pd.DataFrame({"Sample_ID": samples_list,
                         "OverrideCycles": override_cycles_list})


def rename_settings_and_data_headers(samplesheet_obj):
    """
    :return:
    """

    for v1_key, v2_key in V2_SAMPLESHEET_HEADER_VALUES.items():
        if v1_key in samplesheet_obj.keys():
            samplesheet_obj[v2_key] = samplesheet_obj.pop(v1_key)

    return samplesheet_obj


def merge_override_cycles_to_samplesheet(samplesheet_obj, override_cycles_df, ignore_missing_samples=False):
    """
    Merge the overridecycles csv
    :return:
    """

    # Join on left-join
    samplesheet_obj["Data"] = pd.merge(left=samplesheet_obj["Data"], right=override_cycles_df,
                                       on="Sample_ID", how="left")
    if not ignore_missing_samples and samplesheet_obj["Data"]["OverrideCycles"].isnull().values.any():
        logging.error("Found missing values for OverrideCycles for some samples")
        logging.error("Use --ignore-missing-samples to truncate samplesheet to those with override cycles specified")
        sys.exit(1)
    else:
        # Need to dropna on rows with missing override cycles
        logging.info("Dropping samples with missing values in OverrideCycles (if there are any)")
        samplesheet_obj["Data"] = samplesheet_obj["Data"].dropna(how="any", subset=["OverrideCycles"])
    return samplesheet_obj


def write_out_samplesheets(samplesheet_obj, out_dir, is_override_cycles, is_v2):
    """
    Write out samplesheets to each csv file
    :return:
    """

    if is_override_cycles:
        for (override_cycle, override_cycle_df) in samplesheet_obj["Data"].groupby("OverrideCycles"):
            # Duplicate samplesheet_obj
            samplesheet_obj_override_copy = samplesheet_obj.copy()
            # Convert df to csv string
            samplesheet_obj_override_copy["Data"] = override_cycle_df.drop(columns=["OverrideCycles"])
            # Update
            override_cycle_midfix = override_cycle.replace(";", "_")
            # Update settings
            samplesheet_obj_override_copy["Settings"]["OverrideCycles"] = override_cycle
            # Write out config
            write_samplesheet(samplesheet_obj=samplesheet_obj_override_copy,
                              output_file=out_dir / "SampleSheet.{}.csv".format(override_cycle_midfix),
                              is_v2=is_v2)

    else:
        write_samplesheet(samplesheet_obj=samplesheet_obj,
                          output_file=out_dir / "SampleSheet.csv",
                          is_v2=is_v2)


def write_samplesheet(samplesheet_obj, output_file, is_v2):
    """
    Write out the samplesheet object and a given file
    :param samplesheet_obj:
    :param output_file:
    :param is_v2
    :return:
    """

    # Rename samplesheet at the last possible moment
    if is_v2:
        samplesheet_obj = rename_settings_and_data_headers(samplesheet_obj)

    # Write the output file
    with open(output_file, 'w') as samplesheet_h:
        for section, section_values in samplesheet_obj.items():
            # Write out the section header
            samplesheet_h.write("[{}]\n".format(section))
            # Write out values
            if type(section_values) == list:  # [Reads]
                # Write out each item in a new line
                samplesheet_h.write("\n".join(section_values))
            elif type(section_values) == dict:
                samplesheet_h.write("\n".join(map(str, ["{},{}".format(key, value)
                                                        for key, value in section_values.items()])))
            elif type(section_values) == pd.DataFrame:
                section_values.to_csv(samplesheet_h, index=False, header=True, sep=",")
            # Add new line before the next section
            samplesheet_h.write("\n\n")


def main():
    # Get args
    args = get_args()

    # Check / set args
    logging.info("Checking args")
    args = set_args(args=args)

    # Read config
    logging.info("Reading samplesheet")
    samplesheet_obj = read_samplesheet_csv(samplesheet_csv_path=args.samplesheet_csv)

    # Configure samplesheet
    logging.info("Configuring samplesheet")
    samplesheet_obj = configure_samplesheet_obj(samplesheet_obj)

    # Override cycles pathway
    if args.override_cycles is not None:
        # Create override_df
        override_cycles_df = merge_samples_and_override_cycles_array_to_df(samples_list=args.samples,
                                                                           override_cycles_list=args.override_cycles)
        logging.info("Merging samplesheet with override cycles")
        # Merge override_df with samplesheet_obj
        samplesheet_obj = merge_override_cycles_to_samplesheet(samplesheet_obj=samplesheet_obj,
                                                               override_cycles_df=override_cycles_df,
                                                               ignore_missing_samples=args.ignore_missing_samples)

    # Write out samplesheets
    write_out_samplesheets(samplesheet_obj=samplesheet_obj,
                           out_dir=args.out_dir,
                           is_override_cycles=False if args.override_cycles is None else True,
                           is_v2=args.v2)


if __name__ == "__main__":
    main()
