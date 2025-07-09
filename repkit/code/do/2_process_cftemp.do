/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Creates panel datasets with counterfactual temperature controls

*******************************************************************************/

log using "${log}2_process_cftemp.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Run setup file
*********************************/
do "${do}0_setup.do"

* Locals for loop
local pre_month = "monthly_"
local method_year = "trend(year) parallel(8)"
local method_bayes = "trend(year) bayes(mean)"
local method_chebyshev = "trend(chebyshev, 4) parallel(8)"

/*********************************
Prepare PRISM dataset
*********************************/
* we keep the grid cell that is closest to the county's centroid
import delimited "${data}fips_county.csv", clear 

replace fips = 46113 if fips == 46102

keep fips latitude longitude
rename latitude latcentroid
rename longitude longcentroid

tempfile fipsCentroid
save `fipsCentroid', replace

************************
use "${data}linkGridnumberFIPS.dta", clear

* not all fips show up in Schlenker data, we only work with those who do
merge m:1 fips using `fipsCentroid', keep(match) nogen

* create latitude and longitude variable
gen lon = -125 + mod(gridNumber-1,1405)/24
	label var lon "longitude of grid centroid (decimal degrees)"
gen lat  = 49.9375+1/48 - ceil(gridNumber/1405)/24
	label var lat  "latitude of grid centroid (decimal degrees)"
		
* calculate distance between grids and centroids
geodist lat lon latcentroid longcentroid, gen(dist)

* keep closest grid to each centroid
bysort fips: egen double minDist = min(dist)

* keep if closest gridpoint
keep if dist == minDist

* transform dataset into matrix 
keep fips gridNumber
mkmat fips gridNumber, matrix(closestGrid)
levelsof fips, local(fipsList)
matrix rownames closestGrid = `fipsList'
matrix colnames closestGrid = fips gridNumber

************************
foreach f of local fipsList{
	
	* for each fips we loop through years
	forvalues year = 1950/2019{
		
		* load file
		use "${raw}PRISM_Schlenker/year`year'/fips`f'.dta", clear
		
		* gen fips and year variables
		gen fips = `f'

		* keep if closest gridpoint
		local gridToKeep = closestGrid["`f'","gridNumber"]
		
		keep if gridNumber == `gridToKeep'
		
		* build average between min and max
		egen tMean = rowmean(tMin tMax)
		drop tMin tMax
		rename tMean tMax
		
		* keep relevant variables
		keep dateNum tMax fips
		
		* save yearly file for a given fips
		tempfile base`f'_`year'
		save `base`f'_`year'', replace
		
	}
}

* Append all fips and years
clear
foreach f of local fipsList{
	forvalues year = 1950/2019{
		append using `base`f'_`year''
	}
}

* Prepare
gen year = year(dateNum)
gen month = month(dateNum)

bysort year: egen avgMaxTemp = mean(tMax)
bysort year: egen medianMaxTemp = median(tMax)

save "${raw}prism_appended.dta", replace

/*********************************
Produce datasets
*********************************/
foreach source in era5 prism_1950 prism_1970 ghcn {
	foreach level in year month {
		foreach method in year bayes chebyshev {

			* ERA 5
			if "`source'" == "era5" {
				use "${raw}countyLevel_US_1970_2019.dta", clear //era5_UScounty_day_1970_2019.dta

				keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
				reshape long avg_temp_daytime avg_temp_day, i(fips year latitude longitude month) j(day)
				drop latitude longitude
				drop if avg_temp_daytime == .

				* Convert to Fahrenheit
				replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32
			}

			* PRISM
			foreach year in 1950 1970 {
				if "`source'" == "prism_`year'" {
					use "${raw}prism_appended.dta", clear

					* Convert to Fahrenheit
					drop if year < `year' | year > 2019
					sort fips year month
					replace tMax = (tMax * 9 / 5) + 32

					gen day = day(dateNum)
					drop dateNum
				}
			}

			* GHCN
			if "`source'" == "ghcn" {
				use "${raw}ghcn_UScountylevel_1968_2016.dta", clear
				drop if TMAX == . | TMIN == .
				gen tmean = (TMAX + TMIN) / 2
			}

			* Process
			cftemp avg_temp_daytime fips month year, binsize(10) lb(10) ub(90) time(`level') `method_`method'' 
			
			save "${temperature}`source'_`pre_`level''_cftemp_F_`method'.dta", replace
			
		}
	}
}

display "Current time: " c(current_date) " " c(current_time)
log close


*******************************************************************************/
* GHCN from Deschenes and Greenstone (2011)

/* local pre_month = "monthly_"
foreach level in year month {
      use "${path}/Haru/data/ghcn_countylevel_1968_2002.dta", clear
      
	* Temperature
	/* cftemp tmean fips month year, binsize(10) lb(10) ub(90) time(`level') parallel(8)
	save "${path}/Haru/processed/ghcn_`pre_`level''UScounty_1968_2002_cftemp.dta", replace */

	* Precipitation
	cftemp prcp fips month year, binsize(5) lb(10) ub(60) time(`level') parallel(8) realonly
	ds real_*
	foreach var in `r(varlist)' {
		rename `var' prcp_`var'
	}
	save "${path}/Haru/processed/ghcn_`pre_`level''UScounty_1968_2002_cftemp_prcp.dta", replace
      
} */

