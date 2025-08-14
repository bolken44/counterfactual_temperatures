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

log using "${log}2_process_cftemp/2_process_cftemp `task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Parallelize temperature data source and control methods
*********************************/
* Declare which ones
local sources  "era5 prism_1950 prism_1970 ghcn"
local methods  "year bayes chebyshev"
local levels "year month"

* Count items in each dimension
local n_sources  : word count `sources'
local n_methods  : word count `methods'
local n_levels : word count `levels'

* Figure out indices based on task ID
local s_index  = ceil(`task' / (`n_methods' * `n_levels'))
local m_index  = ceil(mod(`task'-1, (`n_methods' * `n_levels')) / `n_levels') + 1
local b_index  = mod(`task'-1, `n_levels') + 1

* Get the actual values
local source  : word `s_index'  of `sources'
local method  : word `m_index'  of `methods'
local level : word `b_index'  of `levels'

* Print to verify
di "Slurm task `task': source=`source', method=`method', level=`level'"

* Make save folder
cap mkdir "${simulations}sim1/"
cap mkdir "${simulations}sim2/"
cap mkdir "${simulations}sim3/"

/*********************************
Locals for loop
*********************************/
local pre_month = "monthly_"
local method_year = "trend(year) parallel(8)"
local method_bayes = "trend(year) bayes(mean)"
local method_chebyshev = "trend(chebyshev, 4) parallel(8)"

/*********************************
Produce datasets
*********************************/
* ERA 5
if "`source'" == "era5" {
	use "${intermediate}era5Land_countylevel_1970_2019.dta", clear //era5_UScounty_day_1970_2019.dta

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
		use "${intermediate}prism_countylevel_1950_2019.dta", clear

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
	clear
	forval i = 1/300 {
		append using "${temp}ghcn_countylevel_1968_2016_`i'.dta"
	}
	
	drop if TMAX == . | TMIN == .
	gen tmean = (TMAX + TMIN) / 2
}

* Process
cftemp avg_temp_daytime fips month year, $bins time(`level') `method_`method'' 

save "${temperature}`source'_UScounty_`pre_`level''cftemp_F_`method'.dta", replace

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

