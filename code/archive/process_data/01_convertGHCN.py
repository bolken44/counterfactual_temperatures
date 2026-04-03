################################################################################
# Takes .dly files from daily GHCN data and converts them to .csv files 
# author: Harufumi Nakazawa, based on code by Cristine
# last modified: 03/27/25
################################################################################

import pandas as pd
import numpy as np
import os
from geopy.distance import geodesic
from tqdm import tqdm
from joblib import Parallel, delayed

path = "/proj/pbolken/climate/Haru/"
data = path + "data/"
ghcn = data + "ghcnd_all/ghcnd_all/"
ghcn_csv = data + "ghcnd_csv/"

# Reset the folder (optional)
# for filename in os.listdir(ghcn_csv):
#     if filename.endswith('.csv'):
#         file_path = os.path.join(ghcn_csv, filename)
#         os.remove(file_path)
#         print(f"Removed file: {file_path}")

################################################################################
### Metadata

# Widths of each column in characters
metadata_col_specs = [
    (0,  12),
    (12, 21),
    (21, 31),
    (31, 38),
    (38, 41),
    (41, 72),
    (72, 76),
    (76, 80),
    (80, 86)
]

# Column names
metadata_names = [
    "ID",
    "LATITUDE",
    "LONGITUDE",
    "ELEVATION",
    "STATE",
    "NAME",
    "GSN FLAG",
    "HCN/CRN FLAG",
    "WMO ID"
]

# Column data types
metadata_dtype = {
    "ID": str,
    "LATITUDE": float,
    "LONGITUDE": float,
    "ELEVATION": float,
    "STATE": str,
    "NAME": str,
    "GSN FLAG": str,
    "HCN/CRN FLAG": str,
    "WMO ID": str
}

################################################################################
### Station level .dly files

# Indices for each level
data_header_names = [
    "ID",
    "YEAR",
    "MONTH",
    "ELEMENT"
]

data_header_col_specs = [
    (0,  11),
    (11, 15),
    (15, 17),
    (17, 21)
]

data_header_dtypes = {
    "ID": str,
    "YEAR": int,
    "MONTH": int,
    "ELEMENT": str}

# Values for each day (1-31 of month)
data_col_names = [
    [
    "VALUE" + str(i + 1), #original files stores them in columns VALUE1 for day 1 of the month, etc
    "MFLAG" + str(i + 1),
    "QFLAG" + str(i + 1),
    "SFLAG" + str(i + 1)
    ]
    for i in range(31) #data_replacement_col_names is a list of lists
] 
data_col_names = sum(data_col_names, []) #flattens it into one long list of tuples

data_replacement_col_names = [
    [
    ("VALUE", i + 1), #to reshape, instead store them as tuple ('VAR_TYPE', 'DAY')
    ("MFLAG", i + 1),
    ("QFLAG", i + 1),
    ("SFLAG", i + 1)
    ]
    for i in range(31)
]
data_replacement_col_names = sum(data_replacement_col_names, [])
data_replacement_col_names = pd.MultiIndex.from_tuples(
    data_replacement_col_names,
    names=['VAR_TYPE', 'DAY']) #assigns level 'VAR_TYPE' to first element in tuple and 'DAY' to second

# Column widths
data_col_specs = [
    [
    (21 + i * 8, 26 + i * 8),
    (26 + i * 8, 27 + i * 8),
    (27 + i * 8, 28 + i * 8),
    (28 + i * 8, 29 + i * 8)
    ]
    for i in range(31)
]
data_col_specs = sum(data_col_specs, [])

# Column data types
data_col_dtypes = [
    {
    "VALUE" + str(i + 1): int,
    "MFLAG" + str(i + 1): str,
    "QFLAG" + str(i + 1): str,
    "SFLAG" + str(i + 1): str
    }
    for i in range(31)
]
data_header_dtypes.update({k: v for d in data_col_dtypes for k, v in d.items()})


################################################################################
# Reading functions

def read_station_metadata(filename):
      """Reads in station metadata

      :filename: ghcnd station metadata file.
      :returns: station metadata as a pandas Dataframe

      """
      df = pd.read_fwf(
            filename, 
            colspecs=metadata_col_specs,  # specify column specs
            names=metadata_names,         # specify column names
            index_col='ID',               # specify index column
            dtype=metadata_dtype          # specify column data types
      )

      return df


def read_ghcn_data_file(filename, variables, include_flags, dropna):
      """Reads in all data from a GHCN .dly data file

      :param filename: path to file
      :param variables: list of variables to include in output dataframe
            e.g. ['TMAX', 'TMIN', 'PRCP']
      :param include_flags: Whether to include data quality flags in the final output
      :param dropna: whether to drop the missing values at this point
      :returns: Pandas dataframe
      """

      df = pd.read_fwf(
            filename,
            colspecs=data_header_col_specs + data_col_specs,
            names=data_header_names + data_col_names,
            index_col=data_header_names,
            dtype=data_header_dtypes
            )

      # print(df.index.get_level_values('ELEMENT').unique())

      unique_elements = df.index.get_level_values('ELEMENT').unique()
      if not all(var in unique_elements for var in variables):
            print("Some variables are missing from the ELEMENT index.")
            return pd.DataFrame()
      
      # Get the weather variables we need
      if variables is not None:
            df = df[df.index.get_level_values('ELEMENT').isin(variables)]

      # Rename the columns
      df.columns = data_replacement_col_names

      # Drop the quality flags
      if not include_flags:
            df = df.loc[:, ('VALUE', slice(None))] 
            #from VAR_TYPE, only keeps the VALUE level and drops MFLAG, QFLAG, SFLAG levels
            #from DAY, slice(None) means "keep all levels" so keeps all days
            df.columns = df.columns.droplevel('VAR_TYPE') # drop the VAR_TYPE level since it is now redundant with VALUE level

      # Reshape
      df = df.stack(level='DAY').unstack(level='ELEMENT')
      #stack(level='DAY') takes columns for each day and turns them into rows (wide to long)
      #unstack(level='ELEMENT') takes rows for each weather variable and turns them into to columns (long to wide)

      # Replace missing values with NaN
      if dropna:
            df.replace(-9999.0, np.nan, inplace=True)
            # df.dropna(how='all', inplace=True)

      # To create unified date indices (note this may drop the station ID as an index)
      df.index = pd.to_datetime(
            df.index.get_level_values('YEAR') * 10000 +
            df.index.get_level_values('MONTH') * 100 +
            df.index.get_level_values('DAY'),
            format='%Y%m%d',
            errors='coerce'
      )

      # Remove rows where the datetime index is NaT
      df = df[~df.index.isna()]
      # print(df.head())
      # duplicates = df[df.index.duplicated(keep=False)]
      # print(duplicates)
      # if not duplicates.empty:
      #       print("Duplicate index values found:")
      #       print(duplicates)
      #       print(duplicates.index.value_counts())
      # else:
      #       print("No duplicates")
      # exit()

      # Reindex df to ensure every date exists (fills missing dates with NaNs)
      full_date_range = pd.date_range(start=df.index.min(), end=df.index.max(), freq='D')
      df = df.reindex(full_date_range)
      
      # Loop through each year to check for missing values
      valid_years = []
      # print(df.columns)
      for year, year_data in df.groupby(df.index.year):
            # Check if all variables are non-missing for each year
            if year_data[variables].notna().all().all():  # .all().all() checks if no NaN in any of the variables
                valid_years.append(year)
        
      # Filter the DataFrame to keep only valid years
      df = df[df.index.year.isin(valid_years)]

      return df

################################################################################
# First read the metadata
metadf = read_station_metadata(f"{data}ghcnd-stations.txt")
variables = ['TMAX', 'TMIN']

# Subset to stations in the US with elevations less than 7000 ft
metadf = metadf[metadf.index.str.startswith("US")]
metadf = metadf[metadf['ELEVATION'] * 3.28084 < 7000]
print(f"Number of stations: {len(metadf)}")

# Function to process a single station
def process_station(station_id):
    
      if not os.path.exists(f"{ghcn}{station_id}.dly"):
            print(f"Skipping station {station_id} because data does not exist.")
            return 0

      ds = read_ghcn_data_file(
            filename=f"{ghcn}{station_id}.dly", 
            variables=variables, 
            include_flags=False, 
            dropna=True
      )

      if not ds.empty:
            ds.reset_index(inplace=True)
            ds.rename(columns={'index': 'date'}, inplace=True)
            ds['station'] = station_id
            print(ds.head())
            ds.to_csv(f'{ghcn_csv}{station_id}.csv', index=False)
            print(f"Station {station_id} saved as csv.")
            return 1  # Count this station
      
      else:
            print(f"Station {station_id} is empty.")
            return 0  # Skip this station

# Run in parallel
# station_counts = 0
# for station_id in metadf.index:
#       station_counts += process_station(station_id)

station_counts = Parallel(n_jobs=-1)(delayed(process_station)(station_id) for station_id in metadf.index)

# Count stations with at least 1 year of data
station_count = sum(station_counts)
print(f"Number of stations present for at least 1 year: {station_count}")