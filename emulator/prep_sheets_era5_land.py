import os
import xarray as xr
import numpy as np
import pandas as pd
from tqdm import tqdm



# Directory containing ERA5 daily mean 2m temperature files
root_era5 = "/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/"

# Years to process
years = [1950, 1960, 1970, 1980, 1990, 2000, 2010, 2020]

# Aggregation level: "5deg" = aggregate to 0.5° grid, "1deg" = keep 0.1° grid
agg_level = "1deg"

# Load county centroid data
county_df = pd.read_csv("/orcd/pool/003/hnaka24/climate/repkit/data/county_centroid.csv")

# Define column labels for the output CSV
columns = ["State", "Fips", "County", "latitude", "longitude", "year", "month", "day", "avg_temp_day"]

# List to store dataframes for each year
all_years_data = []

for year in years:
    # Load ERA5 data for the given year
    ds_era5 = xr.open_dataset(os.path.join(root_era5, f"{year}.nc"), engine="netcdf4").load()

    # Convert temperature from Kelvin to Celsius
    da = ds_era5["t2m"] - 273.15

    if agg_level == "5deg":
        # Aggregate from 0.1° × 0.1° to 0.5° × 0.5° using grouping approach (same as 1_1_1_downloadERA5.py)
        granularity = 0.5
        group_lat = np.floor((da.latitude.values - 0.001) / granularity) + 1
        group_lat = group_lat * granularity
        group_lon = np.floor((da.longitude.values + 0.001) / granularity)
        group_lon = group_lon * granularity

        # Assign group coordinates
        da_coarse = da.assign_coords(group_lat=('latitude', group_lat), group_lon=('longitude', group_lon))

        # Group by latitude groups first, then longitude groups
        da_coarse = da_coarse.groupby('group_lat').mean()
        da_coarse = da_coarse.groupby('group_lon').mean()

        # Rename coordinates back
        da_coarse = da_coarse.rename({'group_lat': 'latitude', 'group_lon': 'longitude'})

        # Shift grid by 0.25° to center the 0.5° grid cells
        # This places grid points at the center of each 0.5° cell instead of at the edges
        da_coarse = da_coarse.assign_coords({
            'latitude': da_coarse.latitude - 0.25,
            'longitude': da_coarse.longitude + 0.25
        })

    data = []
    with tqdm(total=len(county_df)) as pbar:
        for i in range(len(county_df)):
            # Get county information
            county = county_df.loc[[i]]
            county_name = county.iloc[0]["County"]
            state = county.iloc[0]["State"]
            fips = county.iloc[0]["Fips"]

            try:
                # Get county centroid coordinates
                lat = county.iloc[0]["Latitude"]
                lon = county.iloc[0]["Longitude"]

                # Select data for the grid cell closest to the county centroid
                if agg_level == "5deg":
                    county_t2m_da = da_coarse.sel(latitude=lat, longitude=lon, method="nearest")
                elif agg_level == "1deg":
                    county_t2m_da = da.sel(latitude=lat, longitude=lon, method="nearest")
                
                # Get the actual latitude and longitude of the selected grid cell
                selected_lat = float(county_t2m_da.latitude.values)
                selected_lon = float(county_t2m_da.longitude.values)
                
                # Extract time information - handle different possible time dimension names
                time_dim = 'time' if 'time' in county_t2m_da.dims else county_t2m_da.dims[0]
                time_coords = pd.to_datetime(county_t2m_da[time_dim].values)
                
                # Get temperature values as 1D array
                county_t2m = county_t2m_da.values.ravel()
                
                # Create rows for each day
                for day_idx, temp in enumerate(county_t2m):
                    date = time_coords[day_idx]
                    row = {
                        'State': state,
                        'Fips': fips,
                        'County': county_name,
                        'latitude': selected_lat,
                        'longitude': selected_lon,
                        'year': date.year,
                        'month': date.month,
                        'day': date.day,
                        'avg_temp_day': float(temp)
                    }
                    data.append(row)

                # Log progress
                pbar.set_description(f"{county_name} | ({county_t2m.min():.1f}, {county_t2m.mean():.1f}, {county_t2m.max():.1f})")
            except:
                # If county not found in grid cells, skip (e.g. Alaska)
                pbar.set_description(f"{county_name} | NaN")

            # Periodically save intermediate results to CSV
            if (i + 1) % 100 == 0:
                df = pd.DataFrame(data=data, columns=columns)
                # Rename Fips to fips for consistency with Stata
                df = df.rename(columns={'Fips': 'fips'})
                df.to_csv(f"/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/era5_daily_{year}.csv", index=False)
            _ = pbar.update(1)
    
    # Final save to CSV after processing all counties
    df = pd.DataFrame(data=data, columns=columns)
    # Rename Fips to fips for consistency with Stata
    df = df.rename(columns={'Fips': 'fips'})
    df.to_csv(f"/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/era5_daily_{year}.csv", index=False)
    
    # Append to list for combining later
    all_years_data.append(df)

# Combine all years into a single dataframe
print("Combining all years...")
df_all = pd.concat(all_years_data, ignore_index=True)

# Convert to wide format: one row per county-year-month, with columns for each day of month
# Pivot to wide format: one row per fips-year-latitude-longitude-month, columns for each day of month
df_wide = df_all.pivot_table(
    index=['fips', 'year', 'latitude', 'longitude', 'month'],
    columns='day',
    values='avg_temp_day',
    aggfunc='first'
).reset_index()

# Rename day columns to match Stata reshape expectations: avg_temp_day1, avg_temp_day2, etc.
# (numeric suffix, no underscore before number)
new_columns = []
for col in df_wide.columns:
    if col in ['fips', 'year', 'latitude', 'longitude', 'month']:
        new_columns.append(col)
    else:
        # This is a day column, rename to avg_temp_day{number}
        new_columns.append(f'avg_temp_day{int(col)}')
df_wide.columns = new_columns

# Save as .dta file
print("Saving as .dta file...")
df_wide.to_stata(f"/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/era5_daily_all_years_1950_1hr_{agg_level}.dta", write_index=False)
print("Done!")
