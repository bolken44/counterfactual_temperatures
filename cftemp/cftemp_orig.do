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
log using "${path}/Haru/log/cftemp_orig_log_final.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

*******************************************************************************/
use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear

keep fips latitude longitude year month avg_temp_daytime* avg_temp_day*

reshape long avg_temp_daytime avg_temp_day, i(fips latitude longitude year month) j(day)

* drop unnecessary variables
drop latitude longitude

* drop empty variables
drop if avg_temp_daytime == .

************ realized temperatures
* build average yearly temperature and build temperature bins
bysort fips year: egen avg_daytime_temp = mean(avg_temp_daytime)
* build average yearly temperature and build temperature bins
bysort fips year: egen avg_yearly_temp = mean(avg_temp_day)

* create binned variables of realized temperatures
gen under_n10 	= (avg_temp_daytime < - 10)
gen temp_n10_n5 = (avg_temp_daytime >= -10 	& avg_temp_daytime < -5)
gen temp_n5_0 	= (avg_temp_daytime >= -5 	& avg_temp_daytime < 0)
gen temp_0_5 	= (avg_temp_daytime >= 0 	& avg_temp_daytime < 5)
gen temp_5_10 	= (avg_temp_daytime >= 5 	& avg_temp_daytime < 10)
gen temp_10_15 	= (avg_temp_daytime >= 10 	& avg_temp_daytime < 15)
gen temp_15_20 	= (avg_temp_daytime >= 15 	& avg_temp_daytime < 20)
gen temp_20_25 	= (avg_temp_daytime >= 20 	& avg_temp_daytime < 25)
gen temp_25_30 	= (avg_temp_daytime >= 25 	& avg_temp_daytime < 30)
gen temp_30_35 	= (avg_temp_daytime >= 30 	& avg_temp_daytime < 35)
gen over_35 	= (avg_temp_daytime >= 35)
	
* gen yearly total count in each temperature bin
bysort fips year: ereplace under_n10 	= total(under_n10)
bysort fips year: ereplace temp_n10_n5 	= total(temp_n10_n5)
bysort fips year: ereplace temp_n5_0 	= total(temp_n5_0)
bysort fips year: ereplace temp_0_5 	= total(temp_0_5)
bysort fips year: ereplace temp_5_10 	= total(temp_5_10)
bysort fips year: ereplace temp_10_15 	= total(temp_10_15)
bysort fips year: ereplace temp_15_20 	= total(temp_15_20)
bysort fips year: ereplace temp_20_25 	= total(temp_20_25)
bysort fips year: ereplace temp_25_30 	= total(temp_25_30)
bysort fips year: ereplace temp_30_35 	= total(temp_30_35)
bysort fips year: ereplace over_35 	= total(over_35)

************ counterfactual temperatures
* generate yearly variable that starts in 0
sum year 
local minYear = `r(min)'
gen agno = year - `minYear'
	
* first construct monthly average
bysort fips year month: egen avgMeanTempByMonth = mean(avg_temp_daytime)

* estimate slope of monthly average change across years and fips
preserve
	duplicates drop month avgMeanTempByMonth year fips, force
	levelsof fips, local(fipsCodes)
	foreach fip of local fipsCodes{
		forvalues month = 1/12 {
			reg avgMeanTempByMonth agno if month == `month' & fips == `fip'
			local slope`month'_`fip' = _b[agno]
		}
	}
restore
	
* extract slope
gen slope = .
levelsof fips, local(fipsCodes)
foreach fip of local fipsCodes{
	forvalues month = 1/12{
		replace slope = `slope`month'_`fip'' if month == `month' & fips == `fip'
	}
}
sum slope if fips == 1001, detail

* subtract slope from realized temperatures
gen detrendedTemp = avg_temp_daytime - slope  * agno
sum detrendedTemp, detail
* create expected number of days in each bin for each year
gen expected_under_n10 		= .
gen expected_temp_n10_n5 	= .
gen expected_temp_n5_0 		= .
gen expected_temp_0_5 		= .
gen expected_temp_5_10 		= .
gen expected_temp_10_15 	= .
gen expected_temp_15_20 	= .
gen expected_temp_20_25 	= .
gen expected_temp_25_30 	= .
gen expected_temp_30_35 	= .
gen expected_over_35 		= .

* foreach year we estimate the expected number of days in each bin
levelsof year, local(yearValues)
	
foreach y of local yearValues{
		
	* create count in each temperature bin 
	gen tempExpected_under_n10 	= (detrendedTemp < - 10)
	gen tempExpected_temp_n10_n5 	= (detrendedTemp >= -10 & detrendedTemp < -5)
	gen tempExpected_temp_n5_0 	= (detrendedTemp >= -5 	& detrendedTemp < 0)
	gen tempExpected_temp_0_5 	= (detrendedTemp >= 0 	& detrendedTemp < 5)
	gen tempExpected_temp_5_10 	= (detrendedTemp >= 5 	& detrendedTemp < 10)
	gen tempExpected_temp_10_15 	= (detrendedTemp >= 10 	& detrendedTemp < 15)
	gen tempExpected_temp_15_20 	= (detrendedTemp >= 15 	& detrendedTemp < 20)
	gen tempExpected_temp_20_25 	= (detrendedTemp >= 20 	& detrendedTemp < 25)
	gen tempExpected_temp_25_30 	= (detrendedTemp >= 25 	& detrendedTemp < 30)
	gen tempExpected_temp_30_35 	= (detrendedTemp >= 30 	& detrendedTemp < 35)
	gen tempExpected_over_35 	= (detrendedTemp >= 35)

	bysort fips: ereplace tempExpected_under_n10 	= total(tempExpected_under_n10)
	bysort fips: ereplace tempExpected_temp_n10_n5 	= total(tempExpected_temp_n10_n5)
	bysort fips: ereplace tempExpected_temp_n5_0 	= total(tempExpected_temp_n5_0)
	bysort fips: ereplace tempExpected_temp_0_5 	= total(tempExpected_temp_0_5)
	bysort fips: ereplace tempExpected_temp_5_10 	= total(tempExpected_temp_5_10)
	bysort fips: ereplace tempExpected_temp_10_15 	= total(tempExpected_temp_10_15)
	bysort fips: ereplace tempExpected_temp_15_20 	= total(tempExpected_temp_15_20)
	bysort fips: ereplace tempExpected_temp_20_25 	= total(tempExpected_temp_20_25)
	bysort fips: ereplace tempExpected_temp_25_30 	= total(tempExpected_temp_25_30)
	bysort fips: ereplace tempExpected_temp_30_35 	= total(tempExpected_temp_30_35)
	bysort fips: ereplace tempExpected_over_35 	= total(tempExpected_over_35)
		
	bysort fips: gen N = _N
	sum tempExpected_temp_0_5 if fips == 1001, detail
	
	* store values
	replace expected_under_n10 	= 365 * tempExpected_under_n10 		/ N if year == `y'
	replace expected_temp_n10_n5 	= 365 * tempExpected_temp_n10_n5 	/ N if year == `y'
	replace expected_temp_n5_0 	= 365 * tempExpected_temp_n5_0 		/ N if year == `y'
	replace expected_temp_0_5 	= 365 * tempExpected_temp_0_5 		/ N if year == `y'
	replace expected_temp_5_10 	= 365 * tempExpected_temp_5_10 		/ N if year == `y'
	replace expected_temp_10_15 	= 365 * tempExpected_temp_10_15 	/ N if year == `y'
	replace expected_temp_15_20 	= 365 * tempExpected_temp_15_20 	/ N if year == `y'
	replace expected_temp_20_25 	= 365 * tempExpected_temp_20_25 	/ N if year == `y'
	replace expected_temp_25_30 	= 365 * tempExpected_temp_25_30 	/ N if year == `y'
	replace expected_temp_30_35 	= 365 * tempExpected_temp_30_35 	/ N if year == `y'
	replace expected_over_35 	= 365 * tempExpected_over_35 		/ N if year == `y'
		
	* drop variables 
	sum N, detail
	sum expected_temp_0_5 if fips == 1001, detail
	drop tempExpected* N
		
	* move detrendedMaxTemperature one slot
	replace detrendedTemp = detrendedTemp + slope 
		
}

keep year fips under_* temp_* over_35 expected_* avg_daytime_temp avg_yearly_temp
duplicates drop

order fips year, first

list expected_temp_0_5 if year == 1970 & fips == 1001
save "${path}/Haru/countyLevel_USPanel_1970_2019_orig.dta", replace

display "Current time: " c(current_date) " " c(current_time)
log close
