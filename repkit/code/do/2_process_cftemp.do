/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Creates panel datasets with counterfactual temperature controls

*******************************************************************************
Set Up
*********************************/
args data repkit task
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"

log using "${log}2_process_cftemp/2_process_cftemp_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Parallelize temperature data source and control methods
*********************************/
* Main
local combo1 "era5 year year 10"
local combo2 "era5 bayes year 10"
local combo3 "era5 chebyshev year 10"

* Robustness: alternative binsizes
local combo4 "era5 naive year 5"
local combo5 "era5 naive year 20"

* Robustness: alternative sources
local combo6 "prism_1950 naive year 10"
local combo7 "ghcn naive year 10"

* Robustness: alternative nonlinear specs
local combo8 "era5 naive year kdd"
local combo9 "era5 naive year poly4"

* Experiment (bin over 100)
local combo10 "era5 naive year 10"

* Extract components from the combo based on task
local source = word("`combo`task''", 1)
local method = word("`combo`task''", 2)
local level = word("`combo`task''", 3)
local binsize = word("`combo`task''", 4)

* Print to verify
di "Slurm task `task': source=`source', method=`method', level=`level', binsize=`binsize'"

/*********************************
Locals for loop
*********************************/
local pre_month = "monthly_"
local method_naive = "realonly parallel(8)"
local method_year = "trend(year) bayes(none) parallel(8)"
local method_bayes = "trend(year) bayes(mean)"
local method_chebyshev = "trend(chebyshev, 4) parallel(8)"

/*********************************
Produce cftemp datasets
*********************************/
* ERA 5
if "`source'" == "era5" & "`binsize'" != "kdd" & "`binsize'" != "poly4" {
	use "${intermediate}era5Land_countylevel_1970_2019.dta", clear
	/* use "/orcd/pool/003/hnaka24/climate/data/countyLevel_US_1970_2019.dta", clear */

	keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
	reshape long avg_temp_daytime avg_temp_day, i(fips year latitude longitude month) j(day)
	drop latitude longitude
	drop if avg_temp_daytime == .

	* Convert to Fahrenheit
	replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32
	local temp_var "avg_temp_daytime"
}

* PRISM
foreach year in 1950 1970 {
	if "`source'" == "prism_`year'" {
		use "${intermediate}prism_countylevel_1950_2019.dta", clear

		* Convert to Fahrenheit
		drop if year < `year' | year > 2019
		sort fips year month
		replace tMax = (tMax * 9 / 5) + 32
		local temp_var "tMax"

		gen day = day(dateNum)
		drop dateNum
	}
}

* GHCN
if "`source'" == "ghcn" {
	/* clear
	forval i = 1/300 {
		append using "${temp}ghcn_countylevel_1968_2016_`i'.dta"
	}
	destring TMAX TMIN, replace
	drop if TMAX == . | TMIN == .
	gen tmean = (TMAX + TMIN) / 2
	compress
	save "${intermediate}ghcn_countylevel_1950_2019.dta", replace */

	use "${intermediate}ghcn_countylevel_1950_2019.dta", clear
	count
	local temp_var "tmean"	
}

* Process and save
if "`binsize'" != "kdd" & "`binsize'" != "poly4" {

	* Compute annual average
	bysort fips year: egen avg_yearly_temp = mean(`temp_var')

	* Process and save
	if `task' != 10 {
		cftemp `temp_var' fips month year, binsize(`binsize') lb($lb) ub($ub) time(`level') keep(avg_yearly_temp) `method_`method''
		save "${temperature}`source'_UScounty_`pre_`level''cftemp_F_bin`binsize'_`method'.dta", replace
	}
	else {
		cftemp `temp_var' fips month year, binsize(`binsize') lb($lb) ub(100) time(`level') keep(avg_yearly_temp) `method_`method''
		save "${temperature}`source'_UScounty_`pre_`level''cftemp_F_bin`binsize'_over100_`method'.dta", replace
	}
	
}

/*********************************
Killing Degree Days (only ERA 5)
*********************************/
if "`source'" == "era5" & "`binsize'" == "kdd" {
	/* use "${intermediate}era5Land_countylevel_1970_2019.dta", clear */
	use "/orcd/pool/003/hnaka24/climate/data/countyLevel_US_1970_2019.dta", clear

	keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
	reshape long avg_temp_daytime avg_temp_day, i(fips year latitude longitude month) j(day)
	drop latitude longitude
	drop if avg_temp_daytime == .

	* Convert to Fahrenheit
	replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32
	
	* Find max temp of dataset
	sum avg_temp_daytime
	local maxtemp = floor(`r(max)')

	* Loop over thresholds
	forval t = 80(5)95 {

		* Count number of days at each degree above the threshold
		forval k = `t'/`maxtemp' {
			gen count = (avg_temp_daytime >= `k' & avg_temp_daytime < `k' + 1)
			bysort fips year: egen countsum`k' = total(count) // number of days in this bin
			replace countsum`k' = countsum`k' * (`k' + 0.5 - `t') // weighted by distance of bin to threshold
			drop count
		}

		* Sum across the degrees
		egen kdd`t' = rowtotal(countsum*) // total weighted sum
		drop countsum*
	}

	* Collapse to fips-year level
	collapse (mean) kdd* avg_yearly_temp = avg_temp_daytime, by(fips year)
	save "${temperature}`source'_UScounty_`pre_`level''kdd_F.dta", replace

}

/*********************************
Carleton et al (2022) Polynomials
*********************************/
if "`source'" == "era5" & "`binsize'" == "poly4" {

	/* use "${intermediate}era5Land_countylevel_1970_2019.dta", clear */
	use "/orcd/pool/003/hnaka24/climate/data/countyLevel_US_1970_2019.dta", clear

      keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
      reshape long avg_temp_daytime avg_temp_day, i(fips year latitude longitude month) j(day)
      drop latitude longitude
      drop if avg_temp_daytime == .

      * Convert
      replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32

      * Create polynomials
      forval i = 1/4 {
            gen temp_poly_`i' = avg_temp_daytime ^ `i'
      }

      * Sum
      collapse (sum) temp_poly_* (mean) avg_yearly_temp = avg_temp_daytime, by(year fips)

      save "${temperature}`source'_UScounty_`pre_`level''poly4_F.dta", replace
}

display "Current time: " c(current_date) " " c(current_time)
log close


*******************************************************************************/
* GHCN from Deschenes and Greenstone (2011)

/* local pre_month = "monthly_"
foreach level in year month {
      use "${path}/Haru/data/ghcn_countylevel_1968_2002.dta", clear
      
	cftemp tmean fips month year, $bins time(`level') parallel(8)
	save "${path}/Haru/processed/ghcn_`pre_`level''UScounty_1968_2002_cftemp.dta", replace
      
} */

