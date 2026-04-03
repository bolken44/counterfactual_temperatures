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
log using "${path}/Haru/log/cftemp_log.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

* To make each runtime short, create a test dataset with:
use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear
keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
reshape long avg_temp_daytime avg_temp_day, i(fips year  latitude longitude month) j(day)
drop latitude longitude
drop if avg_temp_daytime == .

* Average temp
bysort fips year: egen avg_daytime_temp = mean(avg_temp_daytime)
bysort fips year: egen avg_yearly_temp = mean(avg_temp_day)

/* keep if fips < 2000
keep if year < 1981
save  "${path}/Haru/bigtestdata.dta", replace */

* Test 
/* use "${path}/Haru/testdata.dta", clear */
adopath + "${path}/Haru"
run "${path}/Haru/cftemp.ado"
cftemp avg_temp_daytime fips month year, binsize(5) lb(-10) ub(35) agg(month) parallel(8)
list exp_0_5 if year == 1970 & fips == 1001
save "${path}/Haru/monthly_countyLevel_USPanel_1970_2019_cftemp.dta", replace

display "Current time: " c(current_date) " " c(current_time)
log close

* Help File (requires UI, still rough draft)
/* help cftemp */