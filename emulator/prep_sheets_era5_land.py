import os
import xarray as xr
import numpy as np
import pandas as pd
from tqdm import tqdm



# Directory containing ERA5 daily mean 2m temperature files
root_era5 = "/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/"

# Years to process
years = [1970, 1980, 1990, 2000, 2010]

# Load county centroid data
county_df = pd.read_csv("/orcd/pool/003/hnaka24/climate/repkit/data/county_centroid.csv")

# Define temperature bins ranges
bins = np.concatenate(([-np.inf], np.arange(-20, 46, 1), [np.inf]))

# Define column labels for the output CSV
bins_labels = ["<-20"] + [f"({i},{i+1})" for i in range(-20, 45)] + [">45"] + ["Mean"]
columns = ["State", "Fips", "County"] + bins_labels


for year in years:
    # Load ERA5 data for the given year
    ds_era5 = xr.open_dataset(os.path.join(root_era5, f"{year}.nc"), engine="netcdf4").load()

    # Convert temperature from Kelvin to Celsius
    da = ds_era5["t2m"] - 273.15
    
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

            try:
                # Get county centroid coordinates
                lat = county.iloc[0]["Latitude"]
                lon = county.iloc[0]["Longitude"]

                # Select data for the grid cell closest to the county centroid (using coarsened data)
                county_t2m = da_coarse.sel(latitude=lat, longitude=lon, method="nearest").values.ravel()

                # Compute bin counts over the year
                counts, _ = np.histogram(county_t2m, bins=bins)

                # Compute mean temperature over the year
                μ = county_t2m.mean()

                # Log progress and wrap mean in array
                pbar.set_description(f"{county_name} | ({county_t2m.min():.1f}, {μ:.1f}, {county_t2m.max():.1f})")
                μ = np.array([μ])
            except:
                # If county not found in grid cells, fill with NaNs (e.g. Alaska)
                counts = np.full(len(bins) - 1, np.nan)
                μ = np.full(1, np.nan)
                pbar.set_description(f"{county_name} | NaN")

            # Combine metadata, counts, and mean into a single row
            metadata = county[["State", "Fips", "County"]].values.squeeze()
            row = np.concatenate((metadata, counts, μ))

            # Append row to data list
            data.append(row)

            # Periodically save intermediate results to CSV
            if (i + 1) % 100 == 0:
                df = pd.DataFrame(data=data, columns=columns)
                df.to_csv(f"/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/era5_counts_{year}.csv", index=False)
            _ = pbar.update(1)
    
    # Final save to CSV after processing all counties
    df = pd.DataFrame(data=data, columns=columns)
    df.to_csv(f"/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/era5_counts_{year}.csv", index=False)
