################################################################################
# Takes .dly files from daily GHCN data and converts them to .csv files 
# author: Harufumi Nakazawa, based on code by Cristine
# last modified: 03/27/25
################################################################################

import pandas as pd
import os
path = "/proj/pbolken/climate/Haru/"
data = path + "data/"
ghcn = data + "ghcnd_all/ghcnd_all/"
ghcn_csv = data + "ghcnd_csv/"

################################################################################
# Append all of the station-level csvs
csv_files = [f for f in os.listdir(ghcn_csv) if f.endswith('.csv')]
print(len(csv_files))
df_list = []

# Loop through each CSV file and read it into a DataFrame
for csv_file in csv_files:
    file_path = os.path.join(ghcn_csv, csv_file)
    print(f"Reading file: {file_path}")  # Debugging line to see which file is being processed
    df = pd.read_csv(file_path)
    df_list.append(df)

# Concatenate all DataFrames into one
combined_df = pd.concat(df_list, ignore_index=True)
combined_df.to_stata(f"{ghcn_csv}combined_ghcn_data.dta", write_index=False)
print(f"Data saved as: {ghcn_csv}combined_ghcn_data.dta")