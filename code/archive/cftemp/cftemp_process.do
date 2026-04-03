/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Tests the command cftemp

Below is an example of a simple test code for cftemp. Please feel free to experiment.
If running via the MIT Econ server or Dropbox, the below code should work.
If downloading locally, change the global path to your folder, then create a folder 
called "Haru", and move all the attachments in the email there.
*******************************************************************************/

* File paths (change as needed)
global path "/proj/pbolken/climate" //To run from Dropbox, change to the "Temperature and Research" folder
global output "${path}Haru/output/"

ssc install geodist

* Set up command
adopath + "${path}/Haru/cftemp"
run "${path}/Haru/cftemp/cftemp.ado"
run "${path}/Haru/cftemp/cftemp_spline_base.ado"

*******************************************************************************/
* ERA Land 5 (USA)
*******************************************************************************/
/* log using "${path}/Haru/log/cftemp_log_era5_spline.txt", text replace
display "Current time: " c(current_date) " " c(current_time) */

local pre_month = "monthly_"
/* foreach level in year month {
      use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear
      keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
      reshape long avg_temp_daytime avg_temp_day, i(fips year  latitude longitude month) j(day)
      drop latitude longitude
      drop if avg_temp_daytime == .

      * Average temp
      bysort fips year: egen avg_daytime_temp = mean(avg_temp_daytime)
      bysort fips year: egen avg_yearly_temp = mean(avg_temp_day)

      * Process
      cftemp avg_temp_daytime fips month year, binsize(5) lb(-10) ub(35) time(`level') parallel(8)
      save "${path}/Haru/processed/era5_`pre_`level''UScounty_1970_2019_cftemp.dta", replace
} */

* Convert to Fahrenheit
/* foreach level in year { //month 
      use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear
	drop if fips > 1500
      keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
      reshape long avg_temp_daytime avg_temp_day, i(fips year  latitude longitude month) j(day)
      drop latitude longitude
      drop if avg_temp_daytime == .

	* Convert
	replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32

      * Process
      cftemp avg_temp_daytime fips month year, binsize(10) lb(10) ub(90) trend(year) time(`level') //parallel(8)
      save "${path}/Haru/processed/era5_`pre_`level''UScounty_1970_2019_cftemp_F_2.dta", replace
} */

* Convert to Fahrenheit and other methods
/* local method_year = "trend(year)"
local method_bayes = "trend(year) bayes(mean)"
local method_avgtrend = "trend(avg_temp, year month)"
local method_avgtrend_bayes = "trend(avg_temp, year month) bayes(mean)"
local method_chebyshev = "trend(chebyshev, 4)"
local method_splines = "trend(year) splines" //incompatible with Bayes for now
local method_aggregate = "trend(year) aggregate(5)"

foreach level in year { //  month

	foreach trial in year { //avgtrend bayes chebyshev

		use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear
		/* keep if fips == 4013 | fips == 25025 */
		keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
		reshape long avg_temp_daytime avg_temp_day, i(fips year latitude longitude month) j(day)
		drop latitude longitude
		drop if avg_temp_daytime == .

		* Convert
		replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32

		* Process
		cftemp avg_temp_daytime fips month year, binsize(10) lb(10) ub(90) time(`level') `method_`trial'' //parallel(8)
		/* save "${path}/Haru/processed/era5_`pre_`level''UScounty_1970_2019_cftemp_F_`trial'.dta", replace */
	}
} 
exit */
*******************************************************************************/
* ERA Land 5 (MEX)
*******************************************************************************/
* Mexico, empirical binning
* Calculate the percentage of days of extreme bins in all of US across all years
/* use "${path}/Haru/processed/era5_UScounty_1970_2019_cftemp_F.dta", clear

egen days = rowtotal(real*)
collapse (sum) days real*

ds real*
foreach var in `r(varlist)' {
	gen prop_`var' = `var' / days
}
sum prop_real_under_10, meanonly
local under_mean = `r(mean)' * 100
sum prop_real_over_90, meanonly
local over_mean = (1 - `r(mean)') * 100 */

* Bin
/* foreach level in month { // year
	use "${path}/Haru/data/cohen2022/countyLevel_MEX_1970_2019.dta", clear

	egen fips = group(CVE_ENT CVE_MUN)
	unique fips
	duplicates list fips year month
	cap isid fips // there are two grids for one county
	collapse (mean) avg_temp_daytime* (first) CVE_ENT CVE_MUN, by(fips year month)

	reshape long avg_temp_daytime, i(fips CVE_ENT CVE_MUN year month) j(day)
	drop if avg_temp_daytime == .
	dis _N

	replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32
	sum avg_temp_daytime, detail

	* Calculate that percentile
	centile avg_temp_daytime, centile(`under_mean')
	local lb = round(r(c_1), 1)
	centile avg_temp_daytime, centile(`over_mean')
	local ub = round(r(c_1), 1)
	local binsize = round((`ub' - `lb') / 8, 1)
	local ub = round(`lb' + 8 * `binsize', 1)
	dis "lb: `lb', ub: `ub', binsize: `binsize'"

      * Process
      cftemp avg_temp_daytime fips month year, binsize(5) lb(50) ub(90) time(`level') parallel(8) keep(CVE_ENT CVE_MUN)
      save "${path}/Haru/processed/era5_`pre_`level''MEXcounty_1970_2019_cftemp_F_50.dta", replace
}

exit */

/* Mexico, in Celsius following Cohen et al (2022)
foreach level in month year {
      use "${path}/Haru/data/cohen2022/countyLevel_MEX_1970_2019.dta", clear

	egen fips = group(CVE_ENT CVE_MUN)
	unique fips
	duplicates list fips year month
	cap isid fips // there are two grids for one county
	collapse (mean) avg_temp_daytime* (first) CVE_ENT CVE_MUN, by(fips year month)

      reshape long avg_temp_daytime, i(fips CVE_ENT CVE_MUN year month) j(day)
      drop if avg_temp_daytime == .
	dis _N

      * Process
      cftemp avg_temp_daytime fips month year, binsize(4) lb(12) ub(32) time(`level') parallel(8) keep(CVE_ENT CVE_MUN)
      save "${path}/Haru/processed/era5_`pre_`level''MEXcounty_1970_2019_cftemp.dta", replace
}  */

*******************************************************************************/
* ERA Land 5 (IND)
*******************************************************************************/
* India, empirical binning
* Calculate the percentage of days of extreme bins in all of US across all years
/* use "${path}/Haru/processed/era5_UScounty_1970_2019_cftemp_F.dta", clear

egen days = rowtotal(real*)
collapse (sum) days real*

ds real*
foreach var in `r(varlist)' {
	gen prop_`var' = `var' / days
}
sum prop_real_under_10, meanonly
local under_mean = `r(mean)' * 100
sum prop_real_over_90, meanonly
local over_mean = (1 - `r(mean)') * 100 */

* Bin
/* foreach level in year { // year
	use "${path}/Haru/data/outcomes/countyLevel_IND_1970_2019.dta", clear

	egen fips = group(state district)
	unique fips
	duplicates list fips year month
	cap isid fips // there are two grids for one county
	collapse (mean) avg_temp_daytime* (first) state district, by(fips year month)

	reshape long avg_temp_daytime, i(fips state district year month) j(day)
	drop if avg_temp_daytime == .
	dis _N

	replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32
	sum avg_temp_daytime, detail

	* Calculate that percentile
	centile avg_temp_daytime, centile(`under_mean')
	local lb = round(r(c_1), 1)
	centile avg_temp_daytime, centile(`over_mean')
	local ub = round(r(c_1), 1)
	local binsize = round((`ub' - `lb') / 8, 1)
	local ub = round(`lb' + 8 * `binsize', 1)
	dis "lb: `lb', ub: `ub', binsize: `binsize'"

      * Process
      cftemp avg_temp_daytime fips month year, binsize(10) lb(40) ub(100) time(`level') parallel(8) keep(state district)
      save "${path}/Haru/processed/era5_`pre_`level''INDcounty_1970_2019_cftemp_F_10.dta", replace
}

exit */
*******************************************************************************/
* GHCN from Deschenes and Greenstone (2011)
/* log using "${path}/Haru/log/cftemp_log_ghcn.txt", text replace
display "Current time: " c(current_date) " " c(current_time) */

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

* Extended version is on the Engaging cluster version. Migration binning should be done there as well

*******************************************************************************/
* GHCN extended sample (my construction)
/* local pre_month = "monthly_"

local method_avgtrend = "trend(avg_temp, year month)"
local method_bayes = "trend(year) bayes(mean)"
local method_avgtrend_bayes = "trend(avg_temp, year month) bayes(mean)"
local method_chebyshev = "trend(chebyshev, 4)"
local method_splines = "trend(year) splines" //incompatible with Bayes for now
local method_aggregate = "trend(year) aggregate(5)"

foreach level in year { //month 

	foreach trial in chebyshev { // avgtrend avgtrend_bayes 
		use "${path}/Haru/processed/ghcn_UScountylevel_1968_2016.dta", clear
		/* keep if fips == 1001 */

		drop if TMAX == . | TMIN == .
		gen tmean = (TMAX + TMIN) / 2

		cftemp tmean fips month year, binsize(10) lb(10) ub(90) time(`level') `method_`trial'' parallel(8)
		save "${path}/Haru/processed/ghcn_`pre_`level''UScounty_1968_2016_cftemp_F_`trial'.dta", replace

	}
}

log close
exit */
*******************************************************************************/
* GHCN - station level
/* log using "${path}/Haru/log/cftemp_log_ghcn_st.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

local pre_month = "monthly_"
foreach level in year month {
      use "${path}/Haru/data/ghcnd_csv/combined_ghcn_data.dta", clear

	drop if TMAX == . | TMIN == .
	
	gen date_num = date(date, "YMD")
	gen year = year(date_num)
	gen month = month(date_num)
	gen day = day(date_num)
	sum year

	keep if year <= 2016 & year >= 1968	
	gen tmean = (TMAX + TMIN) / 2
	unique station if year <= 2002 & year >= 1968

	bysort station year month: gen month_tag = _n == 1
	bysort station year: egen month_count = total(month_tag)
	sum month_count, detail
	drop if month_count == 1
      
	* Temperature
	cftemp tmean station month year, binsize(10) lb(10) ub(90) time(`level') parallel(8)
	save "${path}/Haru/processed/ghcn_`pre_`level''USstation_1968_2016_cftemp.dta", replace

	* Precipitation
	/* cftemp prcp fips month year, binsize(5) lb(10) ub(60) time(`level') parallel(8) realonly
	ds real_*
	foreach var in `r(varlist)' {
		rename `var' prcp_`var'
	}
	save "${path}/Haru/processed/ghcn_`pre_`level''UScounty_1968_2002_cftemp_prcp.dta", replace */
      
}

exit */

*******************************************************************************/
* PRISM
log using "${path}/Haru/log/cftemp_log_schlenker.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

* we keep the grid cell that is closest to the county's centroid
/* import delimited "${path}/Haru/data/fips_county.csv", clear 

replace fips = 46113 if fips == 46102

keep fips latitude longitude
rename latitude latcentroid
rename longitude longcentroid

tempfile fipsCentroid
save `fipsCentroid', replace

************************
use "${path}/Haru/data/linkGridnumberFIPS.dta", clear

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
		use "${path}/Haru/data/PRISM_Schlenker/year`year'/fips`f'.dta", clear
		
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

save "${path}/Haru/data/PRISM_Schlenker/appended.dta", replace */

* Process
local pre_month = "monthly_"
local method_year = "trend(year)"
local method_avgtrend = "trend(avg_temp, year month)"
local method_bayes = "trend(year) bayes(mean)"
local method_avgtrend_bayes = "trend(avg_temp, year month) bayes(mean)"
local method_chebyshev = "trend(chebyshev, 4)"
local method_splines = "trend(year) splines" //incompatible with Bayes for now
local method_aggregate = "trend(year) aggregate(5)"

foreach level in year { // month 

	foreach trial in chebyshev { // avgtrend avgtrend_bayes year chebyshev splines aggregate

	      use "${path}/Haru/data/PRISM_Schlenker/appended.dta", clear
		/* drop if fips > 1050 */
		drop if year < 1970 | year > 2019
		sort fips year month
		replace tMax = (tMax * 9 / 5) + 32

		gen day = day(dateNum)
		drop dateNum

		cftemp tMax fips month year, binsize(10) lb(10) ub(90) time(`level') `method_`trial'' parallel(8)
		save "${path}/Haru/processed/schlenker_`pre_`level''UScounty_1970_2019_cftemp_F_`trial'.dta", replace
	}
}
exit

*******************************************************************************/
* Mexico GHCN Data from Cohen and Dechezleprêtre (2022)
log using "${path}/Haru/log/cftemp_log_cohen.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

* Temperature
local pre_month = "monthly_"
foreach level in year month { //month year

	use "${path}/Haru/data/cohen2022/MAX_TEMPERATURE_AEJ.dta", clear
	merge 1:1 CVE_ENT CVE_MUN anio mes dia using "${path}/Haru/data/cohen2022/MIN_TEMPERATURE_AEJ.dta"

	keep if anio>=1980

	gen tmean = (TEMP_MIN + TEMP_MAX)/2

	egen fips = group(CVE_ENT CVE_MUN)

	tostring dia, gen(DAY)
	tostring mes, gen(MONTH)
	tostring anio, gen(YEAR)

	gen date = substr(DAY,1,2) + "-" + substr(MONTH,1,2) + "-" + substr(YEAR,1,4)
	gen date2 = date(date, "DMY")

	xtset fips date2
	rename anio year
	rename mes month

      cftemp tmean fips month year, binsize(4) lb(12) ub(32) time(`level') parallel(8) keep(CVE_ENT CVE_MUN)
      save "${path}/Haru/processed/cohen_`pre_`level''mexico_1980_2018_cftemp.dta", replace
}

*******************************************************************************/
display "Current time: " c(current_date) " " c(current_time)
log close