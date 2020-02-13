#!/usr/bin/env python3
import os
import csv
import pandas as pd
import argparse

#read inputs
parser = argparse.ArgumentParser() 
parser.add_argument("--samplesheet", "-s", type=str, required=True)
parser.add_argument("--trackingsheet", "-t", type=str, required=True)
parser.add_argument("--outputFile", "-o", type=str, required=True)

args = parser.parse_args()

#read samplesheet except metadata. Assign metadata to  'samplesheet_metadata' df
samplesheet_metadata = pd.read_csv(args.samplesheet, nrows=21, header=None)
samplesheet = pd.read_csv(args.samplesheet, skiprows=21, header=0)

#convert to samplesheet v2. 
samplesheet.rename(columns={'I7_Index_ID': 'I7_Index', 'I5_Index_ID': 'I5_Index'}, inplace=True)
samplesheet_metadata.replace(to_replace="Adapter", value="AdapterRead1", inplace=True)
#samplesheet_metadata.iloc[17, 0] = "AdapterRead1"


#read tracking sheet
trackingsheet = pd.read_excel(args.trackingsheet, header=0, sheet_name='2019')

# Select valid samples (e.g. WGS currently) from tracking sheet and use a query function on samplesheet to select on the match in trackingsheet
valid_samples = trackingsheet.query("Type=='WGS'")['Sample_ID (SampleSheet)'].unique().tolist()
samplesheet.query("Sample_ID in @valid_samples", inplace=True)

#Concatenate sample sheet metadata and modified samplesheet. Involves a hack to assign same header as 'samplesheet_metadata' df to 'samplesheet'
samplesheet_header = pd.DataFrame(data=samplesheet.columns.tolist(), index=samplesheet_metadata.columns).transpose()
samplesheet.columns = [0,1,2,3,4,5,6,7,8,9,10,11]
samplesheet_WGS=pd.concat([samplesheet_metadata, samplesheet_header, samplesheet], axis=0, ignore_index=True)

#write output to file
samplesheet_WGS.to_csv(args.outputFile, header=False, index=False)