import pandas as pd

df = pd.read_csv("fastqs.csv")

df.sort_values(by="RGSM")
df.set_index(keys="RGSM", drop=False, inplace=True)
rgsms = df["RGSM"].unique().tolist()

for rgsm in rgsms:
    df.loc[df.RGSM==rgsm].to_csv(rgsm+".csv")