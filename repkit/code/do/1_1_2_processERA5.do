

use "/proj/pbolken/climate/DTA_US/2m_temperature_US_1970_2023.dta", clear

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
import delimited "countyShapefiles/county_centroid.csv", clear

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

save "DTA_US/countyLevel_US_1970_2019.dta", replace