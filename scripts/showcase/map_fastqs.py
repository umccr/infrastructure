#!/usr/bin/env python

import os
import argparse
import pandas as pd

#read inputs
parser = argparse.ArgumentParser()
parser.add_argument("--samplesheet", "-i", type=str, required=True)
parser.add_argument("--outputDir", "-o", type=str, required=True)

args = parser.parse_args()

# create output directory if it does not exist
os.makedirs(args.outputDir, exist_ok=True)

df = pd.read_csv(args.samplesheet)

df.sort_values(by="RGSM")
df.set_index(keys="RGSM", drop=False, inplace=True)
rgsms = df["RGSM"].unique().tolist()

for rgsm in rgsms:
    df.loc[df.RGSM==rgsm].to_csv(os.path.join(args.outputDir, rgsm+".csv"), index=False)