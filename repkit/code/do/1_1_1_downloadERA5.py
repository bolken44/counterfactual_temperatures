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
outputFileName = f'2m_hourlyTemperature_US_{startYear}_{endYear}.dta'

log = f'{repkit}log/1_1_processERA5/'

os.makedirs(raw, exist_ok=True)
os.makedirs(temp, exist_ok=True)
os.makedirs(intermediate_path, exist_ok=True)

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

##################################
# API function
##################################
# def cdsApiCall(monthYearList, variable = '2m_temperature'):

#     c = cdsapi.Client()

#     for i in monthYearList:

#         startTime = pd.to_datetime("today").strftime('%Y-%m-%d %H:%M:%S')

#         year = i[0:4]
#         month = i[-2:]

#         print(f"Starting process for {variable}_{year}_{month}.grib")

#         c.retrieve(
#             'reanalysis-era5-land',
#             {
#                 'variable': '2m_temperature',
#                 'year': f'{year}',
#                 'month': f'{month}',
#                 'day': [
#                     '01', '02', '03',
#                     '04', '05', '06',
#                     '07', '08', '09',
#                     '10', '11', '12',
#                     '13', '14', '15',
#                     '16', '17', '18',
#                     '19', '20', '21',
#                     '22', '23', '24',
#                     '25', '26', '27',
#                     '28', '29', '30',
#                     '31',
#                 ],
#                 'time': [
#                     '00:00', '01:00', '02:00',
#                     '03:00', '04:00', '05:00',
#                     '06:00', '07:00', '08:00',
#                     '09:00', '10:00', '11:00',
#                     '12:00', '13:00', '14:00',
#                     '15:00', '16:00', '17:00',
#                     '18:00', '19:00', '20:00',
#                     '21:00', '22:00', '23:00',
#                 ],
#                 'area': [
#                     50, -130, 20, -55,
#                 ],
#                 'data_format': 'grib',
#                 'download_format': 'unarchived',
#             },
#             f'{raw}{variable}_{year}_{month}.grib')

#         endTime = pd.to_datetime("today").strftime('%Y-%m-%d %H:%M:%S')

#         with open(f'{log}grib_log.txt','a+') as file:
#             file.write(f'\n{variable}_{year}_{month}.grib {startTime} {endTime}')

#         print(f"Finished process for {variable}_{year}_{month}.grib")

# ##################################
# # Make the API call
# ##################################
# cdsApiCall(monthYearList)

##################################
# Create csv for each grib file.
##################################
for file in files:

    # Check how many csv files are in CSV folder.
    # If there are more than maxFiles parameters, the program go to sleep and tries again.
    # After 15 tries, if there's no success, the program is exited.

    tries = 0

    for i in range(15):
        csvFiles = list(filter(lambda x: x.startswith('2m_temperature'), os.listdir(f'{raw}')))
        countCsvFiles = len(csvFiles)
        
        if countCsvFiles < maxFiles:
            tries = 0
            print(f"Current csvFiles in CSV folder: {countCsvFiles}. We are good to go! \n")
            break
        tries += 1
        print(f"Try number {tries}. There are {maxFiles} or more files in CSV folder. Going to sleep for {waitTime} seconds.")
        time.sleep(waitTime)

    if tries == 15:
        print("Already tried 15 times without success. Exiting program.")
        break

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

##################################
# Append all csvs and save as dta
##################################
# Create empty dataframe to append things here
df = pd.DataFrame()

# Work with each file on the list
for year in yearList:
	for month in monthList:
		# Define the file path for the CSV file
		file_path = f'2m_temperature_{year}_{month:0>2}US.csv.bz2'
		
		print(f'Starting year {year} and month {month}...')
		
		df_new = csv.read_csv(f'{raw}{file_path}').to_pandas()
		df = pd.concat([df, df_new], ignore_index=True)

# Drop unnecessary columns
df = df.drop(columns=['','date_adjusted','timezone_name','timezone_value','step','date'])

# Rename other columns
df = df.rename(columns={'Value':'temperature', 'year_adjusted': 'year', 'month_adjusted':'month', 'day_adjusted':'day', 'hour_adjusted':'hour','Latitude':'latitude','Longitude':'longitude'})

# Save file
df.to_stata(f'{temp}{outputFileName}', write_index = False)
print('Saved as .dta!')