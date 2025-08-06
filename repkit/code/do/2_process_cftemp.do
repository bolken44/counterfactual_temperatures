/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Creates panel datasets with counterfactual temperature controls

*******************************************************************************
Set Up
*********************************/
args data repkit
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"

log using "${log}2_process_cftemp/2_process_cftemp.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

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
			cftemp avg_temp_daytime fips month year, $bins time(`level') `method_`method'' 
			
			save "${temperature}`source'_UScounty_`pre_`level''cftemp_F_`method'.dta", replace
			
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
      
	cftemp tmean fips month year, $bins time(`level') parallel(8)
	save "${path}/Haru/processed/ghcn_`pre_`level''UScounty_1968_2002_cftemp.dta", replace
      
} */

