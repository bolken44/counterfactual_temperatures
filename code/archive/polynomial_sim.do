/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: May 2025
ACTION: Creates dataset to run fourth-order polynomials spec from Carleton et al (2022)
*******************************************************************************/

* File paths (change as needed)
global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global output "${path}Haru/output/"
local pre_month = "monthly_"

log using "${path}/Haru/log/polynomial_era5.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

*******************************************************************************/
* Make the dataset
/* foreach level in year { //  month
      use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear

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
      collapse (sum) temp_poly_*, by(year fips)

      save "${path}/Haru/processed/era5_`pre_`level''UScounty_1970_2019_poly4_F.dta", replace
}
exit */

*******************************************************************************/
* Sim 2
* set seed
set seed 1642

* add state information
preserve
	import delimited "${path}Haru/data/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

* ERA 5 yearly averages
use "${path}DTA_US/countyLevel_USPanel_1970_2019.dta", clear
      //this uses ERA Land, not ERA 5

drop if year > 2019 | year < 1970
keep fips year avg_yearly_temp //avg_yearly_temp uses whole day avg not daytime avg
/* replace avg_yearly_temp = (avg_yearly_temp * 9 / 5) + 32 */
duplicates drop

tempfile era5_F_avgtemp
save `era5_F_avgtemp'

*******************************************************************************/
use "${path}/Haru/processed/era5_`pre_`level''UScounty_1970_2019_poly4_F.dta", clear

local source = "era5_F"
local method = "poly4"
local ver = "naive"
local slope_str = "1"

local temp = "baselinePeriodTemp"
local time = "year"
local geo = "fips"
local base_ff = "`time'"
local outcome_ff = "1 * `time' * `temp'"
local version = "naive"
local naive_fe = "fips year"

local omit = 55

xtset fips year
drop if year > 2019 | year < 1970

* Merge average temps
merge m:1 year fips using ``source'_avgtemp'
keep if _merge == 3
drop _merge

* add state information
merge m:1 fips using `fipsToState'
/* drop if _merge != 3 */
drop _merge
egen stateCode = group(state)
drop if state == "AK" | state == "PR" | state == "HI"

* create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
gen agno = year
sum year
replace year = year - `r(min)' + 1 //why +1? Ask Cristine

*******************************************************************************/
preserve
      * generate variables to fill
      gen varName = ""
      gen loop = .
      gen coef = .
      gen sE = .
      gen varNum = .
      gen pValue = .

      * Normalize year to start at 1
      sum `time'
      replace `time' = `time' - `r(min)' + 1
      xtset `geo' `time'

      * Save temperature std deviation
      gen temp = `base_ff' * `temp'
      sum temp

      local halfStdDevValue 		= `r(sd)'/2
      local oneStdDevValue 		= `r(sd)'
      local twoStdDevValue	 	= `r(sd)'*2
      local fourStdDevValue	 	= `r(sd)'*4

      drop temp

      * set iteration variable
      local i = 1 //version
      local x = 1 //bin

      * run regression many times 
      forvalues l = 1/1000 {

            * random variable with mean 0 and variance v^2
            gen random_Y = `outcome_ff' + rnormal(0,`twoStdDevValue')

            * regression
            reghdfe random_Y temp_poly_*, absorb(``version'_fe') cluster(`cluster')

            * save coefficient estimates
            forval i = 1/4 {
                  local coef_`i' = _b[temp_poly_`i']
            }

            * save predicted values
            local normalize = `coef_1'*(`omit') + `coef_2'*(`omit')^2 + `coef_3'*(`omit')^3 + `coef_4'*(`omit')^4
            forval temp = 5/95 {
                  cap gen preds_`temp' = .
                  replace preds_`temp' = `coef_1'*(`temp') + `coef_2'*(`temp')^2 + `coef_3'*(`temp')^3 + `coef_4'*(`temp')^4  - `normalize' if _n == `l'
            }

            * drop randomly generated variables to draw again
            drop random_Y
      }

      drop if preds_55 == .

      * generate variables for plot
      forval temp = 5/95 {

            * take percentile of predicted values
            _pctile preds_`temp', nq(1000)
            local p25_`temp' = `r(r25)'
            local p975_`temp' = `r(r975)'
            local coef_`temp' = `r(r500)'
      }

      * graph evolution of coefficients
      clear
      set obs 91
      gen temp = _n + 4    // temps from 5 to 95

      foreach var in coef p25 p975 {
            gen `var' = .
            forval temp = 5/95 {
                  replace `var' = ``var'_`temp'' if temp == `temp'
            }
      }

      *************************** Plotting
      graph twoway ///
            (rarea p975 p25 temp, color("150 170 190")) ///
            (line coef temp, color("31 88 137")), ///
            xlabel(`bin_labels', labsize(small)) ///
            xtitle("") ///
            yline(0, lpattern(dash) lcolor(red)) ///
            ylabel(`ylabels', angle(h)) ///
            legend(order(2 "No correction") position(6) rows(1) `legendhet') `graph'
      cap mkdir "${output}sim2/`source'_`method'/"
      cap mkdir "${output}sim2/`source'_`method'/`ver'/"
      graph export "${output}sim2/`source'_`method'/`ver'/sim2_`ver'_lin`slope_str'_`source'_`method'.pdf", replace

restore

* Display notification for completion
di as txt "Simulation plot ready to be created."