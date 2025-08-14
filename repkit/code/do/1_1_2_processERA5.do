/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: August 2025
ACTION: Processes the raw ERA 5 Land data

*******************************************************************************
Run setup file
*********************************/
args data repkit startyear endyear
global data "`data'"
global repkit "`repkit'"

log using "${repkit}log/1_1_processERA5/1_1_2_processERA5.txt", text replace

do "${repkit}code/do/0_setup.do"

/* log using "${log}1_1_processERA5.txt", text replace */
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Construct county-level ERA 5 data
*********************************/
use "${temp}2m_hourlyTemperature_US_`startyear'_`endyear'.dta", clear

tempfile temperatureERALand
save `temperatureERALand'

* change coordinates to center of grid cell
replace latitude = latitude - 0.25
replace longitude = longitude + 0.25

drop if abs(latitude) > 90

keep latitude longitude
duplicates drop latitude longitude, force

sort latitude longitude
egen coordinateId = group(latitude longitude)

tempfile temperatureCoordinates
save `temperatureCoordinates', replace

* county coordinates
import delimited "${data}county_centroid.csv", clear

geonear fips latitude longitude using `temperatureCoordinates', neighbors(coordinateId latitude longitude)

* keep relevant information
keep fips nid 
rename nid coordinateId

merge m:1 coordinateId using `temperatureCoordinates'
keep if _merge == 3
drop _merge coordinateId

replace latitude = latitude + 0.25
replace longitude = longitude - 0.25

* make panel grow to cover 1970-2019
expand(50)
bysort fips: gen year = _n
replace year = year + 1969

* make panel grow to cover month level information
expand(12)
bysort fips year: gen month = _n

merge m:1 latitude longitude year month using `temperatureERALand'
keep if _merge == 3
drop _merge

save "${intermediate}era5Land_countylevel_1970_2019.dta", replace