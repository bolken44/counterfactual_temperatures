################################################################################
# Takes .dly files from daily GHCN data and converts them to .csv files 
# author: Harufumi Nakazawa, based on code by Cristine
# last modified: 03/27/25
################################################################################

import pandas as pd
import numpy as np
from geopy.distance import geodesic
from tqdm import tqdm
import os
import sys

data = sys.argv[1]
raw = f'{data}raw/'
temp = f'{data}temp/'
ghcn = f"{data}raw/GHCN/"

task_id = int(os.environ.get("SLURM_ARRAY_TASK_ID"))
num_cores = int(os.environ.get("SLURM_CPUS_PER_TASK", 1))
total_jobs = 300

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

      print(df.index.get_level_values('ELEMENT').unique())

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

      # Drop missing values
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
      print(df.head())
      
      # Loop through each year to check for missing values
      valid_years = []
      print(df.columns)
      for year, year_data in df.groupby(df.index.year):
            # Check if all variables are non-missing for each year
            if year_data[variables].notna().all().all():  # .all().all() checks if no NaN in any of the variables
                valid_years.append(year)
        
      # Filter the DataFrame to keep only valid years
      df = df[df.index.year.isin(valid_years)]

      return df

################################################################################
# First read the metadata
metadf = read_station_metadata(f"{ghcn}ghcnd-stations.txt")
variables=['TMAX', 'TMIN', 'PRCP']

# Subset to stations in the US with elevations less than 7000 ft
metadf = metadf[metadf.index.str.startswith("US")]
metadf = metadf[metadf['ELEVATION'] * 3.28084 < 7000]
print(f"Number of stations: {len(metadf)}")

# Loop through each station
# non_empty_count = 0
# all_data = []
# for station_id in metadf.index:
#       if not os.path.exists(f"{ghcn}{station_id}.dly"):
#             continue
#       ds = read_ghcn_data_file(
#             filename=f"{ghcn}{station_id}.dly", 
#             variables=variables, 
#             include_flags=False, 
#             dropna=True
#       )
    
#       if not ds.empty and ds.index.year.isin(set(range(1968, 2003))).any():
#             non_empty_count += 1  # Increment counter if ds is not empty
#             # all_data += ds

# print(f"Number of non-empty datasets: {non_empty_count}")

# exit()

################################################################################
# Import county centroids
counties = pd.read_csv(f"{data}fips_county.csv")

counties['Fips'] = counties['Fips'].replace(46102, 46113)
counties = counties[['Fips', 'Latitude', 'Longitude']]
counties = counties.rename(columns={'Fips': 'fips', 'Latitude': 'latcentroid', 'Longitude': 'longcentroid'})

# Retrieve the number of pages
pages_per_job = len(counties)// total_jobs
extra_pages = len(counties)% total_jobs  # remainder
start_idx = (task_id - 1) * pages_per_job + min(task_id - 1, extra_pages)
end_idx = start_idx + pages_per_job + (1 if task_id <= extra_pages else 0)

counties = counties.iloc[start_idx:end_idx]
loop = tqdm(total=len(counties), desc="Processing counties")

# Loop through all counties
stations_within_radius = {}

for _, county_row in counties.iterrows():
    # Get county's centroid latitude and longitude
    county_fips = county_row['fips']
    latcentroid = county_row['latcentroid']
    longcentroid = county_row['longcentroid']
    
    # Filter metadf for stations within 200 km radius
    nearby_stations = []
    for station_id, station_row in metadf.iterrows():
        # Get station's latitude and longitude
        station_lat = station_row['LATITUDE']
        station_lon = station_row['LONGITUDE']
        
        # Calculate the distance from the county centroid to the station
        distance = geodesic((latcentroid, longcentroid), (station_lat, station_lon)).km
        
        # If within 200 km, add the station ID and distance to the list
        if distance <= 200:
            nearby_stations.append((station_id, distance))
    
    # Store the result in the dictionary, where key is the fips and value is a list of (station_id, distance) tuples
    stations_within_radius[county_fips] = nearby_stations
    loop.update()

################################################################################
# Loop through each county
county_day_data = []

# Loop through each county
loop = tqdm(total=len(stations_within_radius), desc="Processing counties")
for county_fips, stations in stations_within_radius.items():
      print(f"Number of stations for this county: {len(stations)}")
      
      # Initialize an empty DataFrame to store the weighted averages for this county
      county_df = pd.DataFrame(columns=variables)
      
      # Initialize the total weight for this county
      total_weight = 0
      daily_weight_sum = {}
      
      # Loop through each station in the county
      for station_id, distance in stations:
            if not os.path.exists(f"{ghcn}ghchd_all/{station_id}.dly"):
                  continue

            # Read the station's data
            ds = read_ghcn_data_file(
                  filename=f"{ghcn}ghchd_all/{station_id}.dly", 
                  variables=variables, 
                  include_flags=False, 
                  dropna=True
            )
            if ds.empty:
                  print(f"Skipping station {station_id} because its data is empty.")
                  continue
            
            # Calculate the weight as the inverse of squared distance (if distance > 0)
            weight = 1 / (distance * distance) if distance > 0 else 0
            total_weight += weight
        
            # Loop through each day in the station's data
            for day in ds.index:  # ds.index contains the days
                  
                  # Initialize the weight if a new day
                  if day not in daily_weight_sum:
                        daily_weight_sum[day] = 0
                  
                  daily_weight_sum[day] += weight

                  # Create a row for each day
                  weighted_row = {var: ds.loc[day, var] * weight for var in variables}

                  # Add this weighted row to the county dataframe (index by day)
                  if day not in county_df.index:
                        county_df.loc[day] = weighted_row
                  else:
                        # If the day already exists, add the weighted value to it
                        # county_df.loc[day, variables] += np.array([weighted_row[var] for var in variables])
                        county_df.loc[day, variables] = county_df.loc[day, variables].add(pd.Series(weighted_row), fill_value=0)

            print(f"Station {station_id} added.")
      
      # Normalize by the total weight to get the weighted average for each day
      for day in county_df.index:
            county_df.loc[day, variables] /= daily_weight_sum.get(day, 1)
      
      # Add a 'county_fips' column to identify the county
      county_df['fips'] = county_fips
      
      # Add the county_df for this county to the list
      county_day_data.append(county_df)

      loop.update()

# Concatenate all the data for all counties into a single DataFrame
final_df = pd.concat(county_day_data, axis=0)

# Reset index to ensure date is treated as a column
final_df.reset_index(inplace=True)
final_df.rename(columns={'index': 'date'}, inplace=True)

# Convert TMAX and TMIN from tenths of Celsius to Fahrenheit
final_df['TMAX'] = (final_df['TMAX'] * 9/50) + 32
final_df['TMIN'] = (final_df['TMIN'] * 9/50) + 32

# Convert PRCP from tenth of mm to hundredths of inches
final_df['PRCP'] = (final_df['PRCP'] * 100/254)

# Extract year, month, and day into separate columns
final_df['date'] = pd.to_datetime(final_df['date'])
final_df['year'] = final_df['date'].dt.year
final_df['month'] = final_df['date'].dt.month
final_df['day'] = final_df['date'].dt.day

final_df = final_df[(final_df['year'] >= 1968) & (final_df['year'] <= 2016)]

final_df.to_stata(f"{temp}ghcn_countylevel_1968_2016_{task_id}.dta", write_index=False)
print(f"County-day level data saved to {temp}ghcn_countylevel_1968_2016.dta.")