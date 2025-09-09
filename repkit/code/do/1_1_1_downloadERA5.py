################################################################################
# ERALand_api.py
# description: uses copernicus api to download grib files from webpage 
# requirements: startDate and endDate parameters are needed (-s yyyymmdd - e yyyymmdd format)

# US area: 'area': [50, -130, 20, -55]
# Mexico area: 'area': [34, -120, 13, -85]
# India area: 'area': [37, 69, 6, 96]
################################################################################

##################################
# Import Packages
##################################
import cdsapi
import urllib3
import pandas as pd
import argparse
import os
import time
import pyarrow as pa
import pyarrow.csv as csv
import pyarrow.compute as pc
from tqdm import tqdm
import itertools
import numpy as np
from datetime import datetime, timedelta

##################################
# Parse script arguments and create year/month list
##################################
parser = argparse.ArgumentParser()
parser.add_argument('-s','--startDate', required=True)
parser.add_argument('-e','--endDate', required=True)
parser.add_argument('-m','--maxFiles', required=True)
parser.add_argument('-w','--waitTime', required=True)
parser.add_argument('-sy','--startYear', required=True)
parser.add_argument('-ey','--endYear', required=True)
parser.add_argument('-data','--data', required=True)
parser.add_argument('-repkit','--repkit', required=True)
args = parser.parse_args()

startDate = args.startDate
endDate = args.endDate
maxFiles = int(args.maxFiles)
waitTime = int(args.waitTime)
startYear = args.startYear
endYear = args.endYear
data = args.data
repkit = args.repkit

##################################
# Setup
##################################
# Input and output directories 
raw = f'{data}raw/ERA5_Land/'
temp = f'{data}temp/'
outputFileName = f'2m_dailyTemperature_US_{int(startYear) + 1}_{int(endYear) - 1}.dta'

log = f'{repkit}log/1_1_processERA5/'

os.makedirs(raw, exist_ok=True)
os.makedirs(temp, exist_ok=True)

# Deactivate warnings.
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Creates a list with the file names between start and end dates.
monthYearList = pd.date_range(startDate, endDate, freq = 'MS').strftime("%Y-%m").tolist()
yearList = [year for year in range(int(startYear), int(endYear)+1)]
monthList = range(1,13)
files = []

for i in monthYearList:
    year = i[0:4]
    month = i[-2:]
    file = f"2m_temperature_{year}_{month}.grib"
    files.append(file)

# This is the period we actually want
process_monthYearList = pd.date_range(
    f"{int(startYear) + 1}-01-01",
    f"{int(endYear) - 1}-12-31",
    freq="MS"
).strftime("%Y-%m").tolist()
print("Processing months:", process_monthYearList)
process_yearList = [year for year in range(int(startYear) + 1, int(endYear))]
process_monthList = range(1,13)

##################################
# API function
##################################
def cdsApiCall(monthYearList, variable = '2m_temperature'):

    c = cdsapi.Client()

    for i in monthYearList:

        startTime = pd.to_datetime("today").strftime('%Y-%m-%d %H:%M:%S')

        year = i[0:4]
        month = i[-2:]

        print(f"Starting process for {variable}_{year}_{month}.grib")

        c.retrieve(
            'reanalysis-era5-land',
            {
                'variable': '2m_temperature',
                'year': f'{year}',
                'month': f'{month}',
                'day': [
                    '01', '02', '03',
                    '04', '05', '06',
                    '07', '08', '09',
                    '10', '11', '12',
                    '13', '14', '15',
                    '16', '17', '18',
                    '19', '20', '21',
                    '22', '23', '24',
                    '25', '26', '27',
                    '28', '29', '30',
                    '31',
                ],
                'time': [
                    '00:00', '01:00', '02:00',
                    '03:00', '04:00', '05:00',
                    '06:00', '07:00', '08:00',
                    '09:00', '10:00', '11:00',
                    '12:00', '13:00', '14:00',
                    '15:00', '16:00', '17:00',
                    '18:00', '19:00', '20:00',
                    '21:00', '22:00', '23:00',
                ],
                'area': [
                    50, -130, 20, -55,
                ],
                'data_format': 'grib',
                'download_format': 'unarchived',
            },
            f'{raw}{variable}_{year}_{month}.grib')

        endTime = pd.to_datetime("today").strftime('%Y-%m-%d %H:%M:%S')

        with open(f'{log}grib_log.txt','a+') as file:
            file.write(f'\n{variable}_{year}_{month}.grib {startTime} {endTime}')

        print(f"Finished process for {variable}_{year}_{month}.grib")

##################################
# Make the API call
##################################
cdsApiCall(monthYearList)

#################################
# Create csv for each grib file.
#################################
for file in files:

    # Check how many csv files are in CSV folder.
    # If there are more than maxFiles parameters, the program go to sleep and tries again.
    # After 15 tries, if there's no success, the program is exited.

    # tries = 0

    # for i in range(15):
    #     csvFiles = list(filter(lambda x: x.startswith('2m_temperature'), os.listdir(f'{raw}')))
    #     countCsvFiles = len(csvFiles)
        
    #     if countCsvFiles < maxFiles:
    #         tries = 0
    #         print(f"Current csvFiles in CSV folder: {countCsvFiles}. We are good to go! \n")
    #         break
    #     tries += 1
    #     print(f"Try number {tries}. There are {maxFiles} or more files in CSV folder. Going to sleep for {waitTime} seconds.")
    #     time.sleep(waitTime)

    # if tries == 15:
    #     print("Already tried 15 times without success. Exiting program.")
    #     break

    # Starts working in file.
    print(f'Working on {file}... \n')

    fileName = file[:-5]

    for hour in range(1,25):
        # Creates a unformatted csv (with spaces instead of commas to separate and some issues with titles)
        print(f'Writing unformatted csv files {hour}/24. This may take a few minutes...')
        os.system(f'grib_get_data -F "%.2f" -p date,step -w step={hour} {raw}{file} > {temp}{fileName}_unformatted.csv')
 
        inputFile  = open(f'{temp}{fileName}_unformatted.csv', 'r')
        outputFile = open(f'{temp}{fileName}.csv', 'w')

        # Titles repeat for each date in the file so this checks is used to avoid repeated title rows.
        firstLine = True

        print("Writing cleaned csv file. (This may also take a few minutes...)")

        for line in inputFile:
            if line.find('Latitude') == -1 or firstLine:
                line_elements = line.strip().split() # remove leading and trailing blanks, separate variables based on space

                # Sometimes the GRIB file already has commas separating the fields, so we eliminate them
                line_elements = [element.replace(',', '') for element in line_elements]

                # Obtain new line from elements of the line of the unformatted file
                newLine = ','.join(line_elements) + '\n'

                # Write line
                outputFile.write(newLine)

                # Switch firstLine to false to prevent rewriting the column names
                firstLine = False

        inputFile.close()
        outputFile.close()

        # Removes intermediate csv file.
        print('Done! Removing unformatted csv...')
        os.system(f'rm {temp}{fileName}_unformatted.csv')

        # Collapsing the grid at a coarser level
        granularity = 0.5

        print(f'Collapsing to a {granularity}x{granularity} grid ...')
        table = csv.read_csv(f'{temp}{fileName}.csv')

        # Change schema of table to improve efficiency
        new_schema = pa.schema([('Latitude', pa.float32()), ('Longitude', pa.float32()), ('Value', pa.float32()), ('date', pa.int32()), ('step', pa.int8())])
        table = table.cast(new_schema)

        # generate group latitude and longitude
        group_latitude = pc.subtract(table['Latitude'],0.001)
        group_latitude = pc.divide(group_latitude,granularity)
        group_latitude = pc.floor(group_latitude)
        group_latitude = pc.add(group_latitude,1)
        group_latitude = pc.multiply(group_latitude,granularity)
        group_latitude = group_latitude.cast(pa.float32())

        group_longitude = pc.add(table['Longitude'],0.001)
        group_longitude = pc.divide(group_longitude,granularity)
        group_longitude = pc.floor(group_longitude)
        group_longitude = pc.multiply(group_longitude,granularity)
        group_longitude = group_longitude.cast(pa.float32())

        table = table.append_column(pa.field('group_latitude', pa.float32()),group_latitude)
        table = table.append_column(pa.field('group_longitude', pa.float32()),group_longitude)

        group_value = pa.TableGroupBy(table,['step','date','group_latitude','group_longitude']).aggregate([('Value','mean')])
        group_value = group_value.rename_columns(['step', 'date', 'Latitude', 'Longitude', 'Value'])

        # Compressing formatted csv 
        print('Compressing CSV...')
        with pa.CompressedOutputStream(f'{temp}{fileName}_hr{hour}.csv.bz2', "bz2") as out:
            csv.write_csv(group_value, out)

        # Removes uncompressed csv file.
        print(f'Done with file {hour}/24! Removing uncompressed csv... \n')
        os.system(f'rm {temp}{fileName}.csv')

    # Append all 24 datasets into one
    print('Starting to append all files ...')
    for hour in range(1,25):
        if hour == 1:
            table = csv.read_csv(f'{temp}{fileName}_hr{hour}.csv.bz2')
        else:
            new_table = csv.read_csv(f'{temp}{fileName}_hr{hour}.csv.bz2')
            table = pa.concat_tables([table, new_table])
        
        # Remove hourly csv
        os.system(f'rm {temp}{fileName}_hr{hour}.csv.bz2')

    # Compressing final csv 
    print('Compressing final CSV... \n')
    with pa.CompressedOutputStream(f'{temp}{fileName}.csv.bz2', "bz2") as out:
        csv.write_csv(table, out)

print('All files have been processed! \n')

#################################
# Clean the csvs for each month
#################################
Work with each file on the list
for i in process_monthYearList:

	year = i[0:4]
	month = i[-2:]
	
	####################
	# --------- Identify file names that are needed ------------
	# for each year-month combination we need to find the previous and consecutive dates
	pre_date = datetime(int(year),int(month),1) - timedelta(days = 2) # subtract 2 days since the date is set for the first of the month
	pre_month = pre_date.month # extract month
	pre_year = pre_date.year # extract year

	post_date = datetime(int(year),int(month),1) + timedelta(days = 31) # add 31 days since the date is set for the first of the month
	post_month = post_date.month # extract month
	post_year = post_date.year # extract year

	# generate file, as well past and post file names
	file = f"{temp}2m_temperature_{year}_{month}.csv.bz2"
	file_pre = f"{temp}2m_temperature_{pre_year}_{pre_month:0>2}.csv.bz2" # add the :0>2 to ensure that months are always two digits
	file_post = f"{temp}2m_temperature_{post_year}_{post_month:0>2}.csv.bz2"

	####################
	# --------- Read pre CSV files ------------
	# import grib file as csv
	table = csv.read_csv(file_pre) # using pyarrow import csv as table
	df_pre = table.to_pandas() # take table and convert it to pandas table
     
	# keep those observations in the last day of the month 
	df_pre['month'] = (df_pre['date'].astype(str).str[4:6]).astype(int)
	df_pre['day'] = (df_pre['date'].astype(str).str[6:8]).astype(int)
	last_day_pre = df_pre.loc[df_pre['month'] == int(pre_month), 'day'].max() 
	df_pre = df_pre[(df_pre['day'] == last_day_pre) & (df_pre['month'] == int(pre_month))]
	
	# drop date variables that are no longer necessary
	df_pre = df_pre.drop(columns=['month', 'day'])

	# --------- Read post CSV files ------------
	# import grib file as csv
	table = csv.read_csv(file_post) # using pyarrow import csv as table
	df_post = table.to_pandas() # take table and convert it to pandas table
	
	# keep those observations in the first day of the month 
	df_post['day'] = (df_post['date'].astype(str).str[6:8]).astype(int)
	df_post = df_post[df_post['day'] == 1]
	
	# drop date variables that are no longer necessary
	df_post = df_post.drop(columns=['day'])

	####################
	# --------- Read main CSV files ------------
	# import grib file as a csv
	table = csv.read_csv(file) # using pyarrow import csv as table
	df = table.to_pandas() # take table and convert it to pandas table
	print(f'- imported {file}') # print file that was imported

	# append previous dataframes to this one
	df = pd.concat([df, df_pre, df_post], axis=0, ignore_index=True)
	print('- pre and post datasets were appended to the dataset of interest ...')

	####################
	# ---------- Obtain time zone for coordinates --------    
	# attach timezone csv with timezone information
	table = csv.read_csv(f'{data}timezones.csv')
	df_timezones = table.to_pandas()

	# adjust longitude to be between -180 and 180
	df['Longitude'] = (180 + df['Longitude']) % 360 - 180

	# round coordinates of both datasets to ensure perfect merge
	df = df.round({'Latitude': 1, 'Longitude': 1})
	df_timezones = df_timezones.round({'Latitude':1, 'Longitude':1})

	# merge both datasets
	df = pd.merge(df,df_timezones, on = ['Latitude','Longitude'])

	print('- timezone information has been merged ...')
	
	####################
	# obtain offset between utc and local hour
	df['utc_offset_sign'] = df['timezone_value'].astype(str).str[0] # extract sign of offset, positive or negative
	df['utc_offset_size'] = df['timezone_value'].astype(str).str[1:] # extract size of offset
	df['utc_offset_size'] = df['utc_offset_size'].astype(float).astype(int) # transform to number
	df['utc_offset_size'] = df['utc_offset_size'].div(100) # divide by 100 to obtain number in hours 
	df['utc_offset_size'] = df['utc_offset_size'].apply(np.floor) # for those places without integer offsets leave floor

	####################
	# --------- Change temperature to celsius and extract year, month and day from date variable ------------
	df['Value'] = df['Value'] - 273.15 	# convert Kelvin to Celsius
	df['date'] = pd.to_datetime(df['date'].astype(int).astype(str), format="%Y%m%d")
	df['year'] = df['date'].dt.year
	df['month'] = df['date'].dt.month
	df['day'] = df['date'].dt.day
	# df['year'] = (df['date'].astype(str).str[:4]).astype(int)
	# df['month'] = (df['date'].astype(str).str[4:6]).astype(int)
	# df['day'] = (df['date'].astype(str).str[6:8]).astype(int)
	df['date_unadjusted'] = pd.to_datetime(df[['year', 'month', 'day']])

	####################
	# ---------- Generate local time based on timezones --------
	# generate adjusted hour
	df.loc[df['utc_offset_sign'] == "-", ['utc_offset_size']] = -df.loc[df['utc_offset_sign'] == "-", ['utc_offset_size']] # adjust offset sign to positives and negatives depending on sign
	df['local_time_utc'] = df['step'] + df['utc_offset_size'] # combine step and utc offset based on sign
 
	# fix date if local time is not between 1 and 24
	df['date_adjusted'] = df['date_unadjusted'] # generate aditional variable with adjusted datetime
	df.loc[df['local_time_utc'] < 1, 'date_adjusted'] = df['date_adjusted'] - timedelta(days = 1) # change date to day before
	df.loc[df['local_time_utc'] > 24, 'date_adjusted'] = df['date_adjusted'] + timedelta(days = 1) # change date to day after

	# fix local time to ensure it is between 1 and 24
	df['local_time_utc'] = (df['local_time_utc'] % 24) 
		 
	####################
	# --------- Extract year, month and day from adjuted date variable ------------
	df['year_adjusted'] = pd.DatetimeIndex(df['date_adjusted']).year
	df['month_adjusted'] = pd.DatetimeIndex(df['date_adjusted']).month
	df['day_adjusted'] = pd.DatetimeIndex(df['date_adjusted']).day
	df['hour_adjusted'] = df['local_time_utc']
	df.loc[df['hour_adjusted'] == 0, ['hour_adjusted']] = 24 # change hour adjusted from 0 to 24
		
	# drop date variables that are no longer necessary
	df = df.drop(columns=['year', 'month', 'day', 'date_unadjusted', 'utc_offset_sign', 'utc_offset_size', 'local_time_utc'])

	####################
	# --------- Keep those variables that correspond to year and month in question
	df = df[(df['year_adjusted'] == int(year)) & (df['month_adjusted'] == int(month))]
	print('- starting to generate the temperature statistics of interest ...')

	####################
	# --------- Build relevant averages ------------   
	# build coordinate and date groups (we need values at the day level)
	df['coord_groups'] = list(zip(df.Latitude, df.Longitude)) # build coordinate groups
	df['date_groups'] = list(zip(df.month_adjusted, df.year_adjusted, df.day_adjusted)) # build date groups

	# daily average temperature - 1 variable
	avgTempDay_df = df.groupby(['coord_groups','day_adjusted','month_adjusted', 'year_adjusted'], as_index=False)['Value'].mean() # temperature mean across coordinates, year, month and day
	avgTempDay_df['col_name'] = 'avg_temp_day' + avgTempDay_df['day_adjusted'].astype(int).astype(str) # generate column name to reshape dataset
	avgTempDay_df = avgTempDay_df.pivot(index=['coord_groups','year_adjusted','month_adjusted'], columns='col_name', values='Value') # reshape dataset

	# daily max temperature - 1 variable
	maxTempDay_df = df.groupby(['coord_groups','day_adjusted','month_adjusted', 'year_adjusted'], as_index=False)['Value'].max() # temperature max across coordinates, year, month and day
	maxTempDay_df['col_name'] = 'max_temp_day' + maxTempDay_df['day_adjusted'].astype(int).astype(str) # generate column name to reshape dataset
	maxTempDay_df = maxTempDay_df.pivot(index=['coord_groups','year_adjusted','month_adjusted'], columns='col_name', values='Value') # reshape dataset

	# daily min temperature - 1 variable
	minTempDay_df = df.groupby(['coord_groups','day_adjusted','month_adjusted', 'year_adjusted'], as_index=False)['Value'].min() # temperature min across coordinates, year, month and day
	minTempDay_df['col_name'] = 'min_temp_day' + minTempDay_df['day_adjusted'].astype(int).astype(str) # generate column name to reshape dataset
	minTempDay_df = minTempDay_df.pivot(index=['coord_groups','year_adjusted','month_adjusted'], columns='col_name', values='Value') # reshape dataset

	# daytime average temperature (7-18) - 1 variable
	daytime_df = df.loc[(df['hour_adjusted'] >= 7) & (df['hour_adjusted'] <= 18)] # keep those observations with hours between 7 and 18
	avgTempDaytime_df = daytime_df.groupby(['coord_groups','day_adjusted','month_adjusted', 'year_adjusted'], as_index=False)['Value'].mean() # daytime temperature mean across coordinates, year, month and day
	avgTempDaytime_df['col_name'] = 'avg_temp_daytime' + avgTempDaytime_df['day_adjusted'].astype(int).astype(str) # generate column name to reshape dataset
	avgTempDaytime_df = avgTempDaytime_df.pivot(index=['coord_groups','year_adjusted','month_adjusted'], columns='col_name', values='Value') # reshape dataset

	print('- all variables are computed, now build final dataset ...')

	####################
	# --------- Merge all variables together ------------ 
	# merge the other dataframe into one dataframe with all variables
	var_df = pd.merge(avgTempDay_df, maxTempDay_df, how='outer', on='coord_groups')
	var_df = pd.merge(var_df, minTempDay_df, how='outer', on='coord_groups')
	var_df = pd.merge(var_df, avgTempDaytime_df, how='outer', on='coord_groups')
	
	# generate dataset with remaining information	
	group_df = df.groupby(['Latitude','Longitude','coord_groups','year_adjusted','month_adjusted'], as_index=False)['Value'].mean()\
		.rename(columns={'Latitude':'latitude', 'Longitude':'longitude', 'year_adjusted': 'year', 'month_adjusted': 'month'})

	# generate final dataset and get rid of unnecessary variables
	final_df = pd.merge(group_df, var_df, how='outer', on='coord_groups')
	final_df = final_df.drop(columns=['coord_groups', 'Value'])

	print('- final dataset is ready! Now converting to a compressed csv and saving ... \n')

	####################
	# --------- Export as compressed csv ------------ 

	filenameout = f'{temp}2m_temperature_{year}_{month}_proc.csv.bz2'
	final_df.to_csv(filenameout, compression='bz2')

	print('- done!')


##################################
# Append all csvs and save as dta
##################################
# Create empty dataframe to append things here
df = pd.DataFrame()

# Work with each file on the list
for year, month in tqdm(itertools.product(process_yearList, process_monthList), 
                        total=len(process_yearList)*len(process_monthList), 
                        desc="Processing"):
    # Define the file path for the CSV file
    file_path = f'2m_temperature_{year}_{month:0>2}_proc.csv.bz2'
    
    print(f'Starting year {year} and month {month}...')
    
    df_new = csv.read_csv(f'{temp}{file_path}').to_pandas()
    df = pd.concat([df, df_new], ignore_index=True)

# Extract year, month, day
# df_new["year"] = df_new["date"].str[:4].astype(int)
# df_new["month"] = df_new["date"].str[4:6].astype(int)
# df_new["day"] = df_new["date"].str[6:8].astype(int)

# Drop unnecessary columns
df = df.drop(columns=[''])

# Rename other columns
df = df.rename(columns={'Latitude':'latitude','Longitude':'longitude'})

# Save file
df.to_stata(f'{temp}{outputFileName}', write_index = False)
print(f'Saved as {temp}{outputFileName}!')