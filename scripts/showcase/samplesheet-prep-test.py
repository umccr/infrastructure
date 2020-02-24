#!/usr/bin/env python3
import os
import csv
import pandas as pd
import argparse

#read inputs
parser = argparse.ArgumentParser() 
parser.add_argument("--samplesheet", "-s", type=str, required=True)
parser.add_argument("--trackingsheet", "-t", type=str, required=True)
parser.add_argument("--outputPath", "-o", type=str, required=True)

args = parser.parse_args()

# create output directory if it does not exist
# output_dir = os.path.dirname(args.outputFile)
os.makedirs(args.outputPath, exist_ok=True)

#read samplesheet except metadata. Assign metadata to  'samplesheet_metadata' df
samplesheet_metadata = pd.read_csv(args.samplesheet, nrows=21, header=None)
samplesheet = pd.read_csv(args.samplesheet, skiprows=21, header=0)

#convert to samplesheet v2. 
samplesheet.rename(columns={'I7_Index_ID': 'I7_Index', 'I5_Index_ID': 'I5_Index'}, inplace=True)
samplesheet_metadata.replace(to_replace="Adapter", value="AdapterRead1", inplace=True)
#samplesheet_metadata.iloc[17, 0] = "AdapterRead1"

#read tracking sheet
trackingsheet1 = pd.read_excel(args.trackingsheet, header=0, sheet_name='2019')
trackingsheet2 = pd.read_excel(args.trackingsheet, header=0, sheet_name='2020')
trackingsheet = trackingsheet1.append(trackingsheet2, ignore_index = True)

#extract samplesheet header
samplesheet_header = pd.DataFrame(data=samplesheet.columns.tolist(), index=samplesheet_metadata.columns).transpose()
#find sample types in trackingsheet
sample_type = ['WGS', 'WTS']

for stype in sample_type:
    # Select valid samples (WGS and WTS currently) from tracking sheet and use a query function on samplesheet to select on the match in trackingsheet
    valid_samples = trackingsheet.query('Type==@stype')['Sample_ID (SampleSheet)'].unique().tolist()
    samplesheet_tmp = samplesheet.query("Sample_ID in @valid_samples")
    #assign same header as 'samplesheet_metadata' df to 'samplesheet_tmp'
    col_rename=0
    for col in samplesheet_tmp:
        samplesheet_tmp.rename(columns={col:col_rename}, inplace=True)
        col_rename=col_rename+1
    #concatenate sample sheet metadata and modified samplesheeta. Involves a hack to a
    samplesheet_write=pd.concat([samplesheet_metadata, samplesheet_header, samplesheet_tmp], axis=0, ignore_index=True)
    #write output to file
    samplesheet_name = stype.join(["SampleSheet_", ".csv"])
    samplesheet_write.to_csv(os.path.join(args.outputPath, samplesheet_name), header=False, index=False)