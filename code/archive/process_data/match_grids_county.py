"""
Created: April 2025
Author: Harufumi Nakazawa
Input:
    Data 1: administrative geographic units and their centroids 
    Data 2: daily weather data at the grid level, downloaded from ERA 5 Land

Output:
    Daily weather data at the admin geographic unit level
"""

import pandas as pd
import geopandas as gpd
from shapely.geometry import Point

path = "/proj/pbolken/climate/"

df_list = []
pd.set_option('display.max_columns', None)
pd.set_option('display.width', None)

# ################################################################################
# # MEXICO
# mexico = f"{path}Haru/data/cohen2022/"
# ################################################################################
# # Load county-level data
# df_counties = pd.read_stata(f"{mexico}ARCH933.DTA")
# df_counties['LON_DEC'] = df_counties['LON_DEC'].astype(float)
# df_counties['LAT_DEC'] = df_counties['LAT_DEC'].astype(float)

# # Calculate the mean of the coordinates for the localities inside the municipality
# df_avg_coords = (
#     df_counties
#     .groupby(['CVE_ENT', 'CVE_MUN'], as_index=False)[['LON_DEC', 'LAT_DEC']]
#     .mean()
# )
# print(len(df_avg_coords))  # Should be 2456

# # Create GeoDataFrame with geometry and geographic CRS
# df_avg_coords['geometry'] = df_avg_coords.apply(lambda row: Point(row['LON_DEC'], row['LAT_DEC']), axis=1)
# gdf_counties = gpd.GeoDataFrame(df_avg_coords, geometry='geometry', crs='EPSG:4326')

# # Load grid-level data
# df_grid = pd.read_stata(f"{path}DTA_yearly/2m_temperature_Mexico_1970_2019.dta")

# # Drop duplicate grid points to get one point per location
# df_grid_unique = df_grid.drop_duplicates(subset=['longitude', 'latitude']).copy()

# # Create GeoDataFrame for unique grid points
# df_grid_unique['geometry'] = df_grid_unique.apply(lambda row: Point(row['longitude'], row['latitude']), axis=1)
# gdf_grid = gpd.GeoDataFrame(df_grid_unique, geometry='geometry', crs='EPSG:4326')

# # Reproject both GeoDataFrames to a projected CRS (Web Mercator)
# gdf_counties_proj = gdf_counties.to_crs(epsg=3857)
# gdf_grid_proj = gdf_grid.to_crs(epsg=3857)

# # Spatial join: find the nearest grid point to each county
# nearest_match = gpd.sjoin_nearest(gdf_counties_proj, gdf_grid_proj, how='left', distance_col='distance')

# # Keep only the columns needed to join later
# nearest_match = nearest_match[['CVE_ENT', 'CVE_MUN', 'longitude', 'latitude']]

# # Merge full grid (with time) with nearest_match
# df_merged = df_grid.merge(nearest_match, on=['longitude', 'latitude'], how='inner')

# # Check shape. should be be (2456 x 50 x 12, ...)
# print(df_merged.shape)

# # Drop geometry if not needed and check shape
# if 'geometry' in df_merged.columns:
#     df_merged = df_merged.drop(columns='geometry')

# # Save to Stata
# df_merged.to_stata(f"{mexico}countyLevel_MEX_1970_2019.dta", write_index=False)
# print(f"Processed dataset saved at {mexico}countyLevel_MEX_1970_2019.dta")

################################################################################
# INDIA
outcomes = f"{path}Haru/data/outcomes/"
################################################################################
# Load county-level data
df_counties = pd.read_stata(f"{outcomes}IND_cleaned_merged.dta")
df_counties['centroid_x'] = df_counties['centroid_x'].astype(float)
df_counties['centroid_y'] = df_counties['centroid_y'].astype(float)

# Calculate the mean of the coordinates for the localities inside the municipality
df_avg_coords = (
    df_counties
    .groupby(['state', 'district'], as_index=False)[['centroid_x', 'centroid_y']]
    .mean()
)
print(len(df_avg_coords))  # Should be 2456

# Create GeoDataFrame with geometry and geographic CRS
df_avg_coords['geometry'] = df_avg_coords.apply(lambda row: Point(row['centroid_x'], row['centroid_y']), axis=1)
gdf_counties = gpd.GeoDataFrame(df_avg_coords, geometry='geometry', crs='EPSG:4326')

# Load grid-level data
df_grid = pd.read_stata(f"{path}DTA_yearly/2m_temperature_India_1970_2019.dta")

# Drop duplicate grid points to get one point per location
df_grid_unique = df_grid.drop_duplicates(subset=['longitude', 'latitude']).copy()

# Create GeoDataFrame for unique grid points
df_grid_unique['geometry'] = df_grid_unique.apply(lambda row: Point(row['longitude'], row['latitude']), axis=1)
gdf_grid = gpd.GeoDataFrame(df_grid_unique, geometry='geometry', crs='EPSG:4326')

# Reproject both GeoDataFrames to a projected CRS (Web Mercator)
gdf_counties_proj = gdf_counties.to_crs(epsg=3857)
gdf_grid_proj = gdf_grid.to_crs(epsg=3857)

# Spatial join: find the nearest grid point to each county
nearest_match = gpd.sjoin_nearest(gdf_counties_proj, gdf_grid_proj, how='left', distance_col='distance')

# Keep only the columns needed to join later
nearest_match = nearest_match[['state', 'district', 'longitude', 'latitude']]

# Merge full grid (with time) with nearest_match
df_merged = df_grid.merge(nearest_match, on=['longitude', 'latitude'], how='inner')

# Check shape. should be be (2456 x 50 x 12, ...)
print(df_merged.shape)

# Drop geometry if not needed and check shape
if 'geometry' in df_merged.columns:
    df_merged = df_merged.drop(columns='geometry')

# Save to Stata
df_merged.to_stata(f"{outcomes}countyLevel_IND_1970_2019.dta", write_index=False)
print(f"Processed dataset saved at {outcomes}countyLevel_IND_1970_2019.dta")