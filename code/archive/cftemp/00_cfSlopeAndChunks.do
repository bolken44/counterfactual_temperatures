/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Tests the command cftemp

AUTHOR: Cristine von Dessauer
DATE: March 2025
ACTION: Extract slope for building counterfactuals

Below is an example of a simple test code for cftemp. Please feel free to experiment.
If running via the MIT Econ server or Dropbox, the below code should work.
If downloading locally, change the global path to your folder, then create a folder 
called "Haru", and move all the attachments in the email there.
*******************************************************************************/

clear all
set more off
set varabbrev off

* File paths (change as needed)
global path "/proj/pbolken/climate" //To run from Dropbox, change to the "Temperature and Research" folder

cd "${path}"

* Process dataset:
use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear

keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
reshape long avg_temp_daytime avg_temp_day, i(fips year  latitude longitude month) j(day)
drop latitude longitude
drop if avg_temp_daytime == .

* Average temp
bysort fips year: egen avg_daytime_temp = mean(avg_temp_daytime)
bysort fips year: egen avg_yearly_temp = mean(avg_temp_day)

* Test 
run "${path}/cftemp_slope.ado"
cftemp_slope avg_temp_daytime fips month year, binsize(5) lb(-10) ub(35) agg(year) parallel(8)

save "temp.dta", replace

* Keep relevant variables (this is in celsius, we need to transform to F at some point)
keep fips year month day avg_temp_daytime slope

* store number of times slope needs to be added (removed) from daily temp
forvalues y = 1970(1)2019{
	local lowerBound = `y' - 5
	local upperBound = `y' + 5
	gen slopeTimes`y' = .
		replace slopeTimes`y' = -5 if year == `lowerBound'
		replace slopeTimes`y' = -4 if year == `lowerBound' + 1
		replace slopeTimes`y' = -3 if year == `lowerBound' + 2
		replace slopeTimes`y' = -2 if year == `lowerBound' + 3
		replace slopeTimes`y' = -1 if year == `lowerBound' + 4
		replace slopeTimes`y' = 1 if year == `upperBound' - 4
		replace slopeTimes`y' = 2 if year == `upperBound' - 3
		replace slopeTimes`y' = 3 if year == `upperBound' - 2
		replace slopeTimes`y' = 4 if year == `upperBound' - 1
		replace slopeTimes`y' = 5 if year == `upperBound'
}

* select days that construct counterfactual for each year (10 year interval)
forvalues y = 1970(1)2019{
	local lowerBound = `y' - 5
	local upperBound = `y' + 5
	gen dailyTemp`y' = avg_temp_daytime if (inrange(year,`lowerBound',`upperBound') & year != `y')	
	* move daily temp according to slope
	replace dailyTemp`y' = dailyTemp`y' - slopeTimes`y'*slope
	* transform to Fahrenheit 
	replace dailyTemp`y' = (dailyTemp`y' * 9/5) + 32
}

* transform to fahrenheit
replace avg_temp_daytime = (avg_temp_daytime * 9/5) + 32

************ realized temperatures
* build average yearly temperature and build temperature bins
bysort fips year: egen avg_yearly_temp = mean(avg_temp_daytime)

* create binned variables of realized temperatures
gen under_10 	= (avg_temp_daytime < 10)
gen temp_10_20 	= (avg_temp_daytime >= 10 	& avg_temp_daytime < 20)
gen temp_20_30 	= (avg_temp_daytime >= 20 	& avg_temp_daytime < 30)
gen temp_30_40 	= (avg_temp_daytime >= 30 	& avg_temp_daytime < 40)
gen temp_40_50 	= (avg_temp_daytime >= 40 	& avg_temp_daytime < 50)
gen temp_50_60 	= (avg_temp_daytime >= 50 	& avg_temp_daytime < 60)
gen temp_60_70 	= (avg_temp_daytime >= 60 	& avg_temp_daytime < 70)
gen temp_70_80 	= (avg_temp_daytime >= 70 	& avg_temp_daytime < 80)
gen temp_80_90 	= (avg_temp_daytime >= 80 	& avg_temp_daytime < 90)
gen over_90 	= (avg_temp_daytime >= 90)
	
* gen yearly total count in each temperature bin
bysort fips year: ereplace under_10 	= total(under_10)
bysort fips year: ereplace temp_10_20 	= total(temp_10_20)
bysort fips year: ereplace temp_20_30 	= total(temp_20_30)
bysort fips year: ereplace temp_30_40 	= total(temp_30_40)
bysort fips year: ereplace temp_40_50 	= total(temp_40_50)
bysort fips year: ereplace temp_50_60 	= total(temp_50_60)
bysort fips year: ereplace temp_60_70 	= total(temp_60_70)
bysort fips year: ereplace temp_70_80 	= total(temp_70_80)
bysort fips year: ereplace temp_80_90 	= total(temp_80_90)
bysort fips year: ereplace over_90 	= total(over_90)

* create expected number of days in each bin for each year
gen expected_under_10 		= .
gen expected_temp_10_20 	= .
gen expected_temp_20_30 	= .
gen expected_temp_30_40 	= .
gen expected_temp_40_50 	= .
gen expected_temp_50_60 	= .
gen expected_temp_60_70 	= .
gen expected_temp_70_80 	= .
gen expected_temp_80_90 	= .
gen expected_over_90 		= .

* calculate counterfactual day count
forvalues y = 1970(1)2019{
	
	gen expected_under_10`y' 	= (dailyTemp`y' < 10)
	gen expected_temp_10_20`y' 	= (dailyTemp`y' >= 10 	& dailyTemp`y' < 20)
	gen expected_temp_20_30`y' 	= (dailyTemp`y' >= 20 	& dailyTemp`y' < 30)
	gen expected_temp_30_40`y' 	= (dailyTemp`y' >= 30 	& dailyTemp`y' < 40)
	gen expected_temp_40_50`y' 	= (dailyTemp`y' >= 40 	& dailyTemp`y' < 50)
	gen expected_temp_50_60`y' 	= (dailyTemp`y' >= 50 	& dailyTemp`y' < 60)
	gen expected_temp_60_70`y' 	= (dailyTemp`y' >= 60 	& dailyTemp`y' < 70)
	gen expected_temp_70_80`y' 	= (dailyTemp`y' >= 70 	& dailyTemp`y' < 80)
	gen expected_temp_80_90`y' 	= (dailyTemp`y' >= 80 	& dailyTemp`y' < 90)
	gen expected_over_90`y' 	= (dailyTemp`y' >= 90) // need to add condition that is not missing
	
	bysort fips: gen N`y' = _N if dailyTemp`y' != .
	
	bysort fips: ereplace expected_under_10`y' 	= total(expected_under_10`y')
	bysort fips: ereplace expected_temp_10_20`y' 	= total(expected_temp_10_20`y')
	bysort fips: ereplace expected_temp_20_30`y' 	= total(expected_temp_20_30`y')
	bysort fips: ereplace expected_temp_30_40`y' 	= total(expected_temp_30_40`y')
	bysort fips: ereplace expected_temp_40_50`y' 	= total(expected_temp_40_50`y')
	bysort fips: ereplace expected_temp_50_60`y' 	= total(expected_temp_50_60`y')
	bysort fips: ereplace expected_temp_60_70`y' 	= total(expected_temp_60_70`y')
	bysort fips: ereplace expected_temp_70_80`y' 	= total(expected_temp_70_80`y')
	bysort fips: ereplace expected_temp_80_90`y' 	= total(expected_temp_80_90`y')
	bysort fips: ereplace expected_over_90`y' 	= total(expected_over_90`y')
}


* calculate counterfactual day count: missings need to be removed from > 90 bin
forvalues y = 1970(1)2019{
	gen missing_`y' = (dailyTemp`y' == .)
	bysort fips: ereplace missing_`y' = total(missing_`y')
	replace expected_over_90`y'  = expected_over_90`y'  - missing_`y'
}

drop day month avg_temp_daytime dailyTemp* slope

duplicates drop

drop N*

* calculate counterfactual day count
forvalues y = 1970(1)2019{	
	egen N`y' = rowtotal(expected_under_10`y'-expected_over_90`y')	
}

* calculate counterfactual day count from total of 365/366 days
egen N = rowtotal(under_10-over_90)	

forvalues y = 1970(1)2019{
	
	replace expected_under_10`y' 	= N * expected_under_10`y' 	/ N`y'
	replace expected_temp_10_20`y' 	= N * expected_temp_10_20`y'	/ N`y'
	replace expected_temp_20_30`y' 	= N * expected_temp_20_30`y'	/ N`y'
	replace expected_temp_30_40`y' 	= N * expected_temp_30_40`y'	/ N`y'
	replace expected_temp_40_50`y' 	= N * expected_temp_40_50`y' 	/ N`y'
	replace expected_temp_50_60`y' 	= N * expected_temp_50_60`y' 	/ N`y'
	replace expected_temp_60_70`y' 	= N * expected_temp_60_70`y' 	/ N`y'
	replace expected_temp_70_80`y' 	= N * expected_temp_70_80`y' 	/ N`y'
	replace expected_temp_80_90`y' 	= N * expected_temp_80_90`y'	/ N`y'
	replace expected_over_90`y' 	= N * expected_over_90`y' 	/ N`y'
	
}

* store values
forvalues y = 1970(1)2019{
	replace expected_under_10 	= expected_under_10`y' 		if year == `y'
	replace expected_temp_10_20 	= expected_temp_10_20`y' 	if year == `y'
	replace expected_temp_20_30 	= expected_temp_20_30`y' 	if year == `y'
	replace expected_temp_30_40	= expected_temp_30_40`y'	if year == `y'
	replace expected_temp_40_50 	= expected_temp_40_50`y'	if year == `y'
	replace expected_temp_50_60 	= expected_temp_50_60`y' 	if year == `y'
	replace expected_temp_60_70 	= expected_temp_60_70`y'	if year == `y'
	replace expected_temp_70_80 	= expected_temp_70_80`y' 	if year == `y'
	replace expected_temp_80_90 	= expected_temp_80_90`y'	if year == `y'
	replace expected_over_90 	= expected_over_90`y'		if year == `y'
}

keep year fips under_10 - over_90 expected_under_10 - expected_over_90
duplicates drop

save "DTA_US/counterfactuals_ObservedData_USCounties_1976_2013.dta", replace

