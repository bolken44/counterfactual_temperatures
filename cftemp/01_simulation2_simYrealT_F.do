/*******************************************************************************
AUTHOR: Cristine von Dessauer
DATE: February 2025
ACTION: Simulation 2: outcome is simulated in binned temperature regressions with 
modern schemed graphs and xaxis that moves from -10 to 35

DATE: March 2025
ACTION: Test counterfactuals with additional fixed effects

DATE: April 2025
ACTION: Change to Fahrenheit
*******************************************************************************/

clear all
set more off
set scheme modern
set varabbrev off

********************************************************************************
** LOAD DATASETS AND SET WORKING DIRECTORY
********************************************************************************

* set working directory

cd "/Users/NIne/Library/CloudStorage/Dropbox/Research/Ben Olken/Temperature and Research/"

* load old dataset since new one does not include yearly temperatures
use "Climate Data/ERA Climate Data/ERA Land Daily/countyLevel_USPanel_1970_2019_v2.dta", clear 
 
keep year fips avg_yearly_temp

tempfile avg_yearly_temp
save `avg_yearly_temp', replace

use "Climate Data/ERA Climate Data/ERA Land Daily/era5_UScounty_1970_2019_cftemp_F.dta", clear // Haru's counterfactuals

merge 1:1 fips year using `avg_yearly_temp', nogen

********************************************************************************
** 1) Prepare dataset for Monte Carlo Analysis
********************************************************************************

* set seed
set seed 1642

* set as panel
xtset fips year
drop if year > 2019 | year < 1970

* add state information

preserve
	import delimited "Panel (ERA Land + WM)/countyLevel/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

merge m:1 fips using `fipsToState'

* drop unnecessary variables
drop _merge

* set as panel
xtset fips year

* encode state variable for fixed effects
egen stateCode = group(state)

* create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
gen agno = year

sum year
replace year = year - `r(min)' + 1

* drop alaska, hawaii and puerto rico
drop if state == "AK" | state == "PR" | state == "HI"

********************************************************************************
** 2) MC SIMULATION 1
********************************************************************************

* generate variables to fill
gen varName = ""
gen loop = .
gen coef = .
gen sE = .
gen varNum = .
gen pValue = .

********************************************************************************
** 3.1) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression (omitted category is 50-60)
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10
	
gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 			if variable == 1
	replace coefficient = `meanCoefreal_10_20' 				if variable == 2
	replace coefficient = `meanCoefreal_20_30' 				if variable == 3
	replace coefficient = `meanCoefreal_30_40' 				if variable == 4
	replace coefficient = `meanCoefreal_40_50' 				if variable == 5
	replace coefficient = 0 								if variable == 6
	replace coefficient = `meanCoefreal_60_70' 				if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 				if variable == 8
	replace coefficient = `meanCoefreal_80_90' 				if variable == 9
	replace coefficient = `meanCoefreal_over_90' 			if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 		if variable == 1
	replace p25 = `p25real_10_20' 			if variable == 2
	replace p25 = `p25real_20_30' 			if variable == 3
	replace p25 = `p25real_30_40' 			if variable == 4
	replace p25 = `p25real_40_50' 			if variable == 5
	replace p25 = `p25real_60_70' 			if variable == 7
	replace p25 = `p25real_70_80' 			if variable == 8
	replace p25 = `p25real_80_90' 			if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 				if variable == 1
	replace p975 = `p975real_10_20' 				if variable == 2
	replace p975 = `p975real_20_30' 				if variable == 3
	replace p975 = `p975real_30_40' 				if variable == 4
	replace p975 = `p975real_40_50' 				if variable == 5
	replace p975 = `p975real_60_70' 				if variable == 7
	replace p975 = `p975real_70_80' 				if variable == 8
	replace p975 = `p975real_80_90' 				if variable == 9
	replace p975 = `p975real_over_90' 				if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_F.pdf", replace

* store results for combined plot
rename variable 	variableNoSolution
rename coefficient 	coefficientNoSolution
rename p25 			p25NoSolution
rename p975 		p975NoSolution

*/

********************************************************************************
** 3.2) MC SIMULATION 2: OUTCOME SIMULATIONS (-YEAR * BASELINETEMP + ERROR)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = - year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_negativeTrend_F.pdf", replace

* store results for combined plot
rename variable 	variableNoSolution
rename coefficient 	coefficientNoSolution
rename p25 			p25NoSolution
rename p975 		p975NoSolution

replace coefficientNoSolution = - coefficientNoSolution
replace p25NoSolution = - p25NoSolution
replace p975NoSolution = - p975NoSolution

graph tw (scatter coefficientNoSolution variableNoSolution) (rcap p25NoSolution p975NoSolution variableNoSolution), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_positiveTrend_F.pdf", replace

*/

********************************************************************************
** 3.3) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR + ERROR)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-.1 .1)) ylabel(-.1(.05).1)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_homogeneousTrend_F.pdf", replace

*/

********************************************************************************
** 4) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (STATExyear FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year##stateCode)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsStateYearFE_F.pdf", replace

* store results for combined plot
rename variable 	variableState
rename coefficient 	coefficientState
rename p25 			p25State
rename p975 		p975State 

*/

********************************************************************************
** 5) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (LAGS)
********************************************************************************
/*
*** for lags we test three versions: 1 lag, 3 lags, 5 lags
* create lag of variables
xtset fips year
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	
	gen lag1`var'  = l1.`var'
	gen lag2`var'  = l2.`var'
	gen lag3`var'  = l3.`var'
	gen lag4`var'  = l4.`var'
	gen lag5`var'  = l5.`var'
}

local lag1 "l1.random_Y lag1*"
local lag3 "l1.random_Y l2.random_Y l3.random_Y lag1* lag2* lag3*"
local lag5 "l1.random_Y l2.random_Y l3.random_Y l4.random_Y l5.random_Y lag1* lag2* lag3* lag4* lag5*"

* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* run estimation for 3 lag versions

foreach lag in 1 3 5{

	xtset fips year
	
	* set iteration variable
	local x = 1

	* run regression 1000 times 
	forvalues l = 1/200{

		* random variable with mean 0 and variance v^2
		gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

		* regression
		reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 `lag`lag'', absorb(fips year)

		* save variables
		foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
		* save lincom values in generated variable
			lincom `var'
			replace varName = "`var'" 		if _n == `x'
			replace varNum 	= `x'*100 		if _n == `x'
			replace coef 	= `r(estimate)' if _n == `x'
			replace sE 		= `r(se)' 		if _n == `x'
			replace pValue 	= `r(p)' 		if _n == `x'
			replace loop 	= `l'			if _n == `x'
		* replace iteration variable
			local x = `x' + 1
		}
	* drop randomly generated variable
	drop random_Y

	}

	* generate variables for plot legend:
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
		* coefficients by group
		gen meanCoef = coef
		replace meanCoef = . if varName != "`var'"
		_pctile meanCoef, nq(1000)
		local p25`var' = `r(r25)'
		local p975`var' = `r(r975)'
		ereplace meanCoef = mean(meanCoef)
		local meanCoef`var': di %3.2f meanCoef
		* drop variables
		drop meanCoef

	}

	* graph evolution of coefficients
	gen variable = _n
		replace variable = . if variable > 10

	gen coefficient = .
		replace coefficient = `meanCoefreal_under_10' 	if variable == 1
		replace coefficient = `meanCoefreal_10_20' if variable == 2
		replace coefficient = `meanCoefreal_20_30' 	if variable == 3
		replace coefficient = `meanCoefreal_30_40' 	if variable == 4
		replace coefficient = `meanCoefreal_40_50' 	if variable == 5
		replace coefficient = 0 	if variable == 6
		replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
		
		replace coefficient = `meanCoefreal_70_80' 	if variable == 8
		replace coefficient = `meanCoefreal_80_90' 	if variable == 9
		replace coefficient = `meanCoefreal_over_90' 	if variable == 10

	gen p25 = .
		replace p25 = `p25real_under_10' 	if variable == 1
		replace p25 = `p25real_10_20' 	if variable == 2
		replace p25 = `p25real_20_30' 	if variable == 3
		replace p25 = `p25real_30_40' 	if variable == 4
		replace p25 = `p25real_40_50' 	if variable == 5
		
		replace p25 = `p25real_60_70' 	if variable == 7
		replace p25 = `p25real_70_80' 	if variable == 8
		replace p25 = `p25real_80_90' 	if variable == 9
		replace p25 = `p25real_over_90' 		if variable == 10
		
	gen p975 = .
		replace p975 = `p975real_under_10' 		if variable == 1
		replace p975 = `p975real_10_20' 	if variable == 2
		replace p975 = `p975real_20_30' 		if variable == 3
		replace p975 = `p975real_30_40' 		if variable == 4
		replace p975 = `p975real_40_50' 		if variable == 5
		
		replace p975 = `p975real_60_70' 	if variable == 7
		replace p975 = `p975real_70_80' 	if variable == 8
		replace p975 = `p975real_80_90' 	if variable == 9
		replace p975 = `p975real_over_90' 		if variable == 10

	sort variable

	* plot results by themselves 
	graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
	*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_lag`lag'.pdf", replace
	
	* store results for combined plot
	rename variable 	variableLag`lag'
	rename coefficient 	coefficientLag`lag'
	rename p25 			p25Lag`lag'
	rename p975 		p975Lag`lag'

}

*/

********************************************************************************
** 6) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_Solution_F.pdf", replace

* store results for combined plot
rename variable 	variableSolution
rename coefficient 	coefficientSolution
rename p25 			p25Solution
rename p975 		p975Solution
	
*/

********************************************************************************
** 7) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (LINEAR TREND)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year fips#c.year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_LinearTrend_F.pdf", replace

* store results for combined plot
rename variable 	variableLinearTrend
rename coefficient 	coefficientLinearTrend
rename p25 			p25LinearTrend
rename p975 		p975LinearTrend

*/

********************************************************************************
** SIMULATION 2: COMBINED GRAPHS COMPARING SOLUTION METHODS
********************************************************************************
/*
replace variableNoSolution = variableNoSolution - 0.1

* state X year

replace variableState = variableState + 0.1
	
	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientState variableState, color("155 52 58")) (rcap p25State p975State variableState, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "State X year FE") position(6) rows(1)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsStateYearFE_Joint_F.pdf", replace

* lags

replace variableLag1 = variableLag1 + 0.1
replace variableLag3 = variableLag3 + 0.1
replace variableLag5 = variableLag5 + 0.1
	
	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientLag1 variableLag1, color("155 52 58")) (rcap p25Lag1 p975Lag1 variableLag1, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "1 Lag of X and Y") position(6) rows(1)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_Lag1_Joint_F.pdf", replace

	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientLag3 variableLag3, color("155 52 58")) (rcap p25Lag3 p975Lag3 variableLag3, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "3 Lags of X and Y") position(6) rows(1)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_Lag3_Joint_F.pdf", replace

	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientLag5 variableLag5, color("155 52 58")) (rcap p25Lag5 p975Lag5 variableLag5, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "5 Lags of X and Y") position(6) rows(1)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_Lag5_Joint_F.pdf", replace

* linear county trend

replace variableLinearTrend = variableLinearTrend + 0.1
	
	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientLinearTrend variableLinearTrend, color("155 52 58")) (rcap p25LinearTrend p975LinearTrend variableLinearTrend, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "County Linear Trend") position(6) rows(1)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_LinearTrend_Joint_F.pdf", replace

* solution

replace variableSolution = variableSolution + 0.1
	
	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientSolution variableSolution, color("155 52 58")) (rcap p25Solution p975Solution variableSolution, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "Counterfactual controls") position(6) rows(1)) yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_Solution_Joint_F.pdf", replace
	
*/

********************************************************************************
** BETA SIMULATION GRAPHS
********************************************************************************

drop varName loop coef sE varNum pValue

gen temp = year * baselinePeriodTemp
sum temp

gen sigma = `r(sd)'
drop temp 

gen varName = ""
	replace varName = "real_under_10" 		if _n == 1
	replace varName = "real_10_20" 			if _n == 2
	replace varName = "real_20_30" 			if _n == 3
	replace varName = "real_30_40" 			if _n == 4 
	replace varName = "real_40_50"  		if _n == 5
	replace varName = "real_60_70" 			if _n == 7
	replace varName = "real_70_80"  		if _n == 8
	replace varName = "real_80_90"  		if _n == 9
	replace varName = "real_over_90" 		if _n == 10

gen varNum = .
	replace varNum = 1 	if varName == "real_under_10" 
	replace varNum = 2 	if varName == "real_10_20" 
	replace varNum = 3 	if varName == "real_20_30" 
	replace varNum = 4 	if varName == "real_30_40"
	replace varNum = 5 	if varName == "real_40_50"
	replace varNum = 6 	if varName == "real_50_60"
	replace varNum = 7 	if varName == "real_60_70"
	replace varNum = 8 	if varName == "real_70_80"
	replace varNum = 9	if varName == "real_80_90"
	replace varNum = 10 if varName == "real_over_90"
	
* we iterate over values for sigma

forvalues beta = 1(1)100{

	* we run each version of sigma/beta 100 times 
	forvalues l = 1/10{ 
	
		local slope = `beta'/10000 * sigma
		
		gen random_Y = (`slope' * baselinePeriodTemp) * year + rnormal(0,sigma)
	
		* run regression
		qui reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)
	
		* save variables
		foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
			gen coef_`var'_`l' = _b[`var']

		} 

		* drop created variables
		drop random_Y 
	}
	* store values
	gen beta_`beta' = .
	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
		egen temp = rowmean(coef_`var'_*)
		replace beta_`beta' = temp if varName == "`var'"
		drop temp
	}
	* drop created variables
	drop coef_*
}

save "temp.dta", replace

* add ommitted category

replace varNum = 6 if _n == 6

forvalues b = 1(1)100{
	replace beta_`b' = 0 if varNum == 6
}

* plot

local plotDescription = "(line beta_1 varNum, lcolor(gs15))"

forvalues beta = 2(2)100{

local plotDescription = "`plotDescription'" + " " + "(line beta_`beta' varNum, lcolor(gs9))"

}

graph tw `plotDescription' (line beta_1 varNum, lcolor(red) lwidth(0.5)) (line beta_25 varNum, lcolor(blue) lwidth(0.5)) (line beta_50 varNum, lcolor(green) lwidth(0.5)) (line beta_100 varNum, lcolor(purple) lwidth(0.5)), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash)) legend(order(52 "{&beta} = 0.0001 {&sigma}" 53 "{&beta}  = 0.0025 {&sigma}" 54 "{&beta}  = 0.005 {&sigma}" 55 "{&beta}  = 0.01 {&sigma}") pos(6) rows(1) size(medsmall))
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_betaOverSigma_positiveTrend_F.pdf", replace

** replace beta for negative beta

forvalues b = 1(1)100{
	replace beta_`b' = - beta_`b'
}

local plotDescription = "(line beta_1 varNum, lcolor(gs15))"

forvalues beta = 2(2)100{

local plotDescription = "`plotDescription'" + " " + "(line beta_`beta' varNum, lcolor(gs9))"

}

graph tw `plotDescription' (line beta_1 varNum, lcolor(red) lwidth(0.5)) (line beta_25 varNum, lcolor(blue) lwidth(0.5)) (line beta_50 varNum, lcolor(green) lwidth(0.5)) (line beta_100 varNum, lcolor(purple) lwidth(0.5)), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash)) legend(order(52 "{&beta} = -0.0001 {&sigma}" 53 "{&beta}  = -0.0025 {&sigma}" 54 "{&beta}  = -0.005 {&sigma}" 55 "{&beta}  = -0.01 {&sigma}") pos(6) rows(1) size(medsmall))
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_betaOverSigma_negativeTrend_F.pdf", replace

restore
*/

********************************************************************************
** 8) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (NO FIX)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-100 200)) ylabel(-100(50)200)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_QuadOutcome_F.pdf", replace

rename variable 	variableNoSolutionQ
rename coefficient 	coefficientNoSolutionQ
rename p25 			p25NoSolutionQ
rename p975 		p975NoSolutionQ

*/

********************************************************************************
** 9) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))  yscale(range(-100 200)) ylabel(-100(50)200)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_QuadOutcome_Solution_F.pdf", replace

rename variable 	variableSolutionQ
rename coefficient 	coefficientSolutionQ
rename p25 			p25SolutionQ
rename p975 		p975SolutionQ

*/

********************************************************************************
** 10) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (LINEAR TREND)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year fips#c.year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))  yscale(range(-100 200)) ylabel(-100(50)200)
* qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_QuadOutcome_LinearTrend_F.pdf", replace

rename variable 	variableLinearTrendQ
rename coefficient 	coefficientLinearTrendQ
rename p25 			p25LinearTrendQ
rename p975 		p975LinearTrendQ


*/
	
********************************************************************************
** 11) MC SIMULATION 2: OUTCOME SIMULATIONS (ln(YEAR) * BASELINETEMP + ERROR) (NO FIX)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = ln(year) * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = ln(year) * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-.2 .3)) ylabel(-.2(.1).3)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_LogOutcome_FipsYearFE.pdf", replace

rename variable 	variableNoSolutionLn
rename coefficient 	coefficientNoSolutionLn
rename p25 			p25NoSolutionLn
rename p975 		p975NoSolutionLn

*/

********************************************************************************
** 12) MC SIMULATION 2: OUTCOME SIMULATIONS (ln(YEAR) * BASELINETEMP + ERROR) (SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = ln(year) * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = ln(year) * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-.2 .3)) ylabel(-.2(.1).3)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_LogOutcome_Solution.pdf", replace

rename variable 	variableSolutionLn
rename coefficient 	coefficientSolutionLn
rename p25 			p25SolutionLn
rename p975 		p975SolutionLn


*/

********************************************************************************
** COMBINATION OF GRAPHS
********************************************************************************
/*
replace variableNoSolutionQ = variableNoSolutionQ - 0.1

* linear county trend (Quadratic outcome)

replace variableLinearTrendQ = variableLinearTrendQ + 0.1
	
	graph tw (scatter coefficientNoSolutionQ variableNoSolutionQ, color("31 88 137")) (rcap p25NoSolutionQ p975NoSolutionQ variableNoSolutionQ, color("31 88 137")) (scatter coefficientLinearTrendQ variableLinearTrendQ, color("155 52 58")) (rcap p25LinearTrendQ p975LinearTrendQ variableLinearTrendQ, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "County Linear Trend") position(6) rows(1)) yscale(range(-100 150)) ylabel(-100(50)150)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_QuadOutcome_LinearTrend_Joint_F.pdf", replace

* solution (Quadratic outcome)

replace variableSolutionQ = variableSolutionQ + 0.1
	
	graph tw (scatter coefficientNoSolutionQ variableNoSolutionQ, color("31 88 137")) (rcap p25NoSolutionQ p975NoSolutionQ variableNoSolutionQ, color("31 88 137")) (scatter coefficientSolutionQ variableSolutionQ, color("155 52 58")) (rcap p25SolutionQ p975SolutionQ variableSolutionQ, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "Counterfactual controls") position(6) rows(1)) yscale(range(-100 150)) ylabel(-100(50)150)
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_QuadOutcome_Solution_Joint_F.pdf", replace

* solution (Ln outcome)

replace variableSolutionLn = variableSolutionLn + 0.1
	
	graph tw (scatter coefficientNoSolutionLn variableNoSolutionLn, color("31 88 137")) (rcap p25NoSolutionLn p975NoSolutionLn variableNoSolutionLn, color("31 88 137")) (scatter coefficientSolutionLn variableSolutionLn, color("155 52 58")) (rcap p25SolutionLn p975SolutionLn variableSolutionLn, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "Counterfactual controls") position(6) rows(1)) 
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_LnOutcome_Solution_Joint_F.pdf", replace

*/	
********************************************************************************
** 13) MC SIMULATION 2: OUTCOME SIMULATIONS (ln(YEAR) * BASELINETEMP + ERROR) (LINEAR TREND)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = ln(year) * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = ln(year) * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year fips#c.year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-.2 .3)) ylabel(-.2(.1).3)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_LogOutcome_LinearTrend.pdf", replace

drop variable coefficient p25 p975 
*/

********************************************************************************
** 14) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR + REAL EFFECT) (NO FIX)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue') + 5 * real_under_10 + 5 * real_over_90

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))

* store results for combined plot
rename variable 	variableNoSolution
rename coefficient 	coefficientNoSolution
rename p25 			p25NoSolution
rename p975 		p975NoSolution

*/

********************************************************************************
** 15) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR + REAL EFFECT) (SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue') + 5 * real_under_10 + 5 * real_over_90

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)

* store results for combined plot
rename variable 	variableSolution
rename coefficient 	coefficientSolution
rename p25 			p25Solution
rename p975 		p975Solution
	
*/

********************************************************************************
** SIMULATION 2: COMBINED GRAPHS COMPARING SOLUTION METHODS (WITH REAL EFFECT)
********************************************************************************
/*
replace variableNoSolution = variableNoSolution - 0.1
replace variableSolution = variableSolution + 0.1

* all combined in one graph

	graph tw 	(scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) ///
				(scatter coefficientSolution variableSolution, color("155 52 58")) (rcap p25Solution p975Solution variableSolution, color("155 52 58")), ///
				xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") ///
				yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) ///
				legend(order(1 "No correction" 3 "Counterfactual control") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_RealEffect_Solution_Joint_F.pdf", replace	
*/

********************************************************************************
** 17) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR + REAL EFFECT) (NO FIX)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue') + 100*real_under_10 + 100*real_10_20 + 100*real_20_30 + 100*real_30_40 + 100*real_40_50 + 100*real_50_60 +100*real_60_70 + 100*real_70_80 + 100*real_80_90 + 100*real_over_90

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE.pdf", replace

* store results for combined plot
rename variable 	variableNoSolution
rename coefficient 	coefficientNoSolution
rename p25 			p25NoSolution
rename p975 		p975NoSolution

*/

********************************************************************************
** 18) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR + REAL EFFECT) (SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue') + 100*real_under_10 + 100*real_10_20 + 100*real_20_30 + 100*real_30_40 + 100*real_40_50 + 100*real_50_60 +100*real_60_70 + 100*real_70_80 + 100*real_80_90 + 100*real_over_90

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_Solution.pdf", replace

* store results for combined plot
rename variable 	variableSolution
rename coefficient 	coefficientSolution
rename p25 			p25Solution
rename p975 		p975Solution
	
*/

********************************************************************************
** 19) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR + REAL EFFECT) (LINEAR TREND)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue') + 100*real_under_10 + 100*real_10_20 + 100*real_20_30 + 100*real_30_40 + 100*real_40_50 + 100*real_50_60 +100*real_60_70 + 100*real_70_80 + 100*real_80_90 + 100*real_over_90

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year fips#c.year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
*qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_LinearTrend.pdf", replace

* store results for combined plot
rename variable 	variableLinearTrend
rename coefficient 	coefficientLinearTrend
rename p25 			p25LinearTrend
rename p975 		p975LinearTrend

*/

********************************************************************************
** SIMULATION 2: COMBINED GRAPHS COMPARING SOLUTION METHODS (WITH REAL EFFECT)
********************************************************************************
/*
replace variableNoSolution = variableNoSolution - 0.1
replace variableSolution = variableSolution + 0.1

* all combined in one graph

	graph tw 	(scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) ///
				(scatter coefficientLinearTrend variableLinearTrend, color("155 52 58")) (rcap p25LinearTrend p975LinearTrend variableLinearTrend, color("155 52 58")) ///
				(scatter coefficientSolution variableSolution, color("94 130 50")) (rcap p25Solution p975Solution variableSolution, color("94 130 50")), ///
				xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") ///
				yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) ///
				legend(order(1 "No correction" 3 "County Linear Trend" 5 "Counterfactual control") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_AllTests_RealEffect_QuadOutcome_Joint_100ForAll.pdf", replace

*/

********************************************************************************
** 20) MC SIMULATION 2: DECADE LEVEL REGRESSIONS
********************************************************************************
/*
preserve

* collapse at the decade level
gen decade = year/10
replace decade = floor(decade)

collapse (sum) exp_* real_* (mean) baselinePeriodTemp, by(decade fips state stateCode)

* find distribution of non randomized outcome part

gen temp = decade * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* generate variables to fill
gen varName = ""
gen loop = .
gen coef = .
gen sE = .
gen varNum = .
gen pValue = .

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/1000{

	* random variable with mean 0 and variance v^2
	gen random_Y = decade * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips decade)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_decadeLevelRegression_F.pdf", replace

restore
*/

********************************************************************************
** 21) MC SIMULATION 2: STATE LEVEL REGRESSIONS
********************************************************************************
/*
preserve

* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* collapse at the state level
collapse (mean) exp_* real_* baselinePeriodTemp, by(year stateCode)

* generate variables to fill
gen varName = ""
gen loop = .
gen coef = .
gen sE = .
gen varNum = .
gen pValue = .

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/1000{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`halfStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(stateCode year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_stateLevelRegression_F.pdf", replace

restore
*/

********************************************************************************
** 22) MC SIMULATION 2: ADAPTATION
********************************************************************************
/*
* divide sample into two: above and below pre temp median

sum baselinePeriodTemp, detail
local medianPreTemp = `r(p50)'

gen aboveMedian = baselinePeriodTemp > `medianPreTemp'

* loop through both types of datasets
foreach value in 0 1{

	preserve

	keep if aboveMedian == `value'
	
	* find distribution of non randomized outcome part

	gen temp = year * baselinePeriodTemp
	sum temp

	local halfStdDevValue 		= `r(sd)'/2
	local oneStdDevValue 		= `r(sd)'
	local twoStdDevValue	 	= `r(sd)'*2
	local fourStdDevValue	 	= `r(sd)'*4

	drop temp

	* set iteration variable
	local x = 1

	* run regression 1000 times 
	forvalues l = 1/200{

		* random variable with mean 0 and variance v^2
		gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

		* regression
		reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

		* save variables
		foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
		* save lincom values in generated variable
			lincom `var'
			replace varName = "`var'" 		if _n == `x'
			replace varNum 	= `x'*100 		if _n == `x'
			replace coef 	= `r(estimate)' if _n == `x'
			replace sE 		= `r(se)' 		if _n == `x'
			replace pValue 	= `r(p)' 		if _n == `x'
			replace loop 	= `l'			if _n == `x'
		* replace iteration variable
			local x = `x' + 1
		}
	* drop randomly generated variable
	drop random_Y

	}

	* generate variables for plot legend:
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
		* coefficients by group
		gen meanCoef = coef
		replace meanCoef = . if varName != "`var'"
		_pctile meanCoef, nq(1000)
		local p25`var' = `r(r25)'
		local p975`var' = `r(r975)'
		ereplace meanCoef = mean(meanCoef)
		local meanCoef`var': di %3.2f meanCoef
		* drop variables
		drop meanCoef

	}

	* graph evolution of coefficients
	gen variable = _n
		replace variable = . if variable > 10

	gen coefficient = .
		replace coefficient = `meanCoefreal_under_10' 	if variable == 1
		replace coefficient = `meanCoefreal_10_20' if variable == 2
		replace coefficient = `meanCoefreal_20_30' 	if variable == 3
		replace coefficient = `meanCoefreal_30_40' 	if variable == 4
		replace coefficient = `meanCoefreal_40_50' 	if variable == 5
		replace coefficient = 0 	if variable == 6
		replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
		
		replace coefficient = `meanCoefreal_70_80' 	if variable == 8
		replace coefficient = `meanCoefreal_80_90' 	if variable == 9
		replace coefficient = `meanCoefreal_over_90' 	if variable == 10

	gen p25 = .
		replace p25 = `p25real_under_10' 	if variable == 1
		replace p25 = `p25real_10_20' 	if variable == 2
		replace p25 = `p25real_20_30' 	if variable == 3
		replace p25 = `p25real_30_40' 	if variable == 4
		replace p25 = `p25real_40_50' 	if variable == 5
		
		replace p25 = `p25real_60_70' 	if variable == 7
		replace p25 = `p25real_70_80' 	if variable == 8
		replace p25 = `p25real_80_90' 	if variable == 9
		replace p25 = `p25real_over_90' 		if variable == 10
		
	gen p975 = .
		replace p975 = `p975real_under_10' 		if variable == 1
		replace p975 = `p975real_10_20' 	if variable == 2
		replace p975 = `p975real_20_30' 		if variable == 3
		replace p975 = `p975real_30_40' 		if variable == 4
		replace p975 = `p975real_40_50' 		if variable == 5
		
		replace p975 = `p975real_60_70' 	if variable == 7
		replace p975 = `p975real_70_80' 	if variable == 8
		replace p975 = `p975real_80_90' 	if variable == 9
		replace p975 = `p975real_over_90' 		if variable == 10

	keep variable* coefficient p25 p975
	
	* store results for combined plot
	rename variable 	variable`value'
	rename coefficient 	coefficient`value'
	rename p25 			p25`value'
	rename p975 		p975`value'
	
	keep if variable`value' != .
	gen count = _n

	tempfile dataset`value'
	save `dataset`value'', replace
	
	restore

}
	use `dataset0', clear
	merge 1:1 count using `dataset1'
	
	* graph
	replace variable0 = variable0 + 0.1
	replace variable1 = variable1 - 0.1
	
	graph tw (scatter coefficient0 variable0, color("31 88 137")) (rcap p250 p9750 variable0, color("31 88 137")) (scatter coefficient1 variable1, color("155 52 58")) (rcap p251 p9751 variable1, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "Below median baseline temperature" 3 "Above median baseline temperature") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_adaptation_F.pdf", replace

*/

********************************************************************************
** 23) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (NO SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_NoSolution.pdf", replace

drop variable coefficient p25 p975

*/

********************************************************************************
** 24) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, noabsorb

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_NoFipsYearFE_Solution.pdf", replace

drop variable coefficient p25 p975

*/

********************************************************************************
** 25) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (SOLUTION + STATExyear FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(stateCode#year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_NoFipsYearFE_SolutionStateYearFE.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 26) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (SOLUTION + fips FE + year FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_Solution.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 27) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (SOLUTION + STATExyear FE + fips FE + year FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year stateCode#year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsYearFE_SolutionStateYearFE.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 28) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (SOLUTION + fips FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_FipsNoYearFE_Solution.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 29) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR * BASELINETEMP + ERROR) (SOLUTION + year FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-2 5)) ylabel(-2(1)5)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_NoFipsYearFE_Solution.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 30) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (NO SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-100 300)) ylabel(-100(100)300)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_QuadOutcome_FipsYearFE_NoSolution.pdf", replace

drop variable coefficient p25 p975

*/

********************************************************************************
** 31) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (SOLUTION)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, noabsorb

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-100 300)) ylabel(-100(100)300)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_QuadOutcome_NoFipsYearFE_Solution.pdf", replace

drop variable coefficient p25 p975

*/

********************************************************************************
** 32) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (SOLUTION + STATExyear FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(stateCode#year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-100 300)) ylabel(-100(100)300)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_QuadOutcome_NoFipsYearFE_SolutionStateYearFE.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 33) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (SOLUTION + fips FE + year FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-100 300)) ylabel(-100(100)300)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_QuadOutcome_FipsYearFE_Solution.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 34) MC SIMULATION 2: OUTCOME SIMULATIONS (YEAR^2 * BASELINETEMP + ERROR) (SOLUTION + STATExyear FE + fips FE + year FE)
********************************************************************************
/*
* find distribution of non randomized outcome part

gen temp = year^2 * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year^2 * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_50_60 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(fips year stateCode#year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
			* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' if variable == 2
	replace coefficient = `meanCoefreal_20_30' 	if variable == 3
	replace coefficient = `meanCoefreal_30_40' 	if variable == 4
	replace coefficient = `meanCoefreal_40_50' 	if variable == 5
	replace coefficient = 0 	if variable == 6
	replace coefficient = `meanCoefreal_60_70' 	if variable == 7 
	
	replace coefficient = `meanCoefreal_70_80' 	if variable == 8
	replace coefficient = `meanCoefreal_80_90' 	if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 	if variable == 2
	replace p25 = `p25real_20_30' 	if variable == 3
	replace p25 = `p25real_30_40' 	if variable == 4
	replace p25 = `p25real_40_50' 	if variable == 5
	
	replace p25 = `p25real_60_70' 	if variable == 7
	replace p25 = `p25real_70_80' 	if variable == 8
	replace p25 = `p25real_80_90' 	if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 	if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	
	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) yscale(range(-100 300)) ylabel(-100(100)300)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_QuadOutcome_FipsYearFE_SolutionStateYearFE.pdf", replace

drop variable coefficient p25 p975
	
*/

********************************************************************************
** 35) MC SIMULATION 2: GHCN
********************************************************************************
/*
use "Climate Data/ERA Climate Data/ERA Land Daily/ghcn_UScounty_1968_2016_cftemp.dta", clear

merge 1:1 fips year using `avg_yearly_temp', nogen

* set seed
set seed 1642

* set as panel
xtset fips year
drop if year > 2019 | year < 1970

* add state information

preserve
	import delimited "Panel (ERA Land + WM)/countyLevel/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

merge m:1 fips using `fipsToState'

* drop unnecessary variables
drop _merge

* set as panel
xtset fips year

* encode state variable for fixed effects
egen stateCode = group(state)

* create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
gen agno = year

sum year
replace year = year - `r(min)' + 1

* drop alaska, hawaii and puerto rico
drop if state == "AK" | state == "PR" | state == "HI"

* generate variables to fill
gen varName = ""
gen loop = .
gen coef = .
gen sE = .
gen varNum = .
gen pValue = .

* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression (omitted category is 50-60)
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10
	
gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 			if variable == 1
	replace coefficient = `meanCoefreal_10_20' 				if variable == 2
	replace coefficient = `meanCoefreal_20_30' 				if variable == 3
	replace coefficient = `meanCoefreal_30_40' 				if variable == 4
	replace coefficient = `meanCoefreal_40_50' 				if variable == 5
	replace coefficient = 0 								if variable == 6
	replace coefficient = `meanCoefreal_60_70' 				if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 				if variable == 8
	replace coefficient = `meanCoefreal_80_90' 				if variable == 9
	replace coefficient = `meanCoefreal_over_90' 			if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 		if variable == 1
	replace p25 = `p25real_10_20' 			if variable == 2
	replace p25 = `p25real_20_30' 			if variable == 3
	replace p25 = `p25real_30_40' 			if variable == 4
	replace p25 = `p25real_40_50' 			if variable == 5
	replace p25 = `p25real_60_70' 			if variable == 7
	replace p25 = `p25real_70_80' 			if variable == 8
	replace p25 = `p25real_80_90' 			if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 				if variable == 1
	replace p975 = `p975real_10_20' 				if variable == 2
	replace p975 = `p975real_20_30' 				if variable == 3
	replace p975 = `p975real_30_40' 				if variable == 4
	replace p975 = `p975real_40_50' 				if variable == 5
	replace p975 = `p975real_60_70' 				if variable == 7
	replace p975 = `p975real_70_80' 				if variable == 8
	replace p975 = `p975real_80_90' 				if variable == 9
	replace p975 = `p975real_over_90' 				if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_GHCN_F.pdf", replace

********************************************************************************
** 36) MC SIMULATION 2: PRISM
********************************************************************************
/*
use "Climate Data/ERA Climate Data/ERA Land Daily/schlenker_UScounty_1950_2019_cftemp_F.dta", clear

merge 1:1 fips year using `avg_yearly_temp', nogen

* set seed
set seed 1642

* set as panel
xtset fips year
drop if year > 2019 | year < 1970

* add state information

preserve
	import delimited "Panel (ERA Land + WM)/countyLevel/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

merge m:1 fips using `fipsToState'

* drop unnecessary variables
drop _merge

* set as panel
xtset fips year

* encode state variable for fixed effects
egen stateCode = group(state)

* create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
gen agno = year

sum year
replace year = year - `r(min)' + 1

* drop alaska, hawaii and puerto rico
drop if state == "AK" | state == "PR" | state == "HI"

* generate variables to fill
gen varName = ""
gen loop = .
gen coef = .
gen sE = .
gen varNum = .
gen pValue = .

* find distribution of non randomized outcome part

gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local x = 1

* run regression 1000 times 
forvalues l = 1/200{

	* random variable with mean 0 and variance v^2
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`twoStdDevValue')

	* regression (omitted category is 50-60)
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)

	* save variables
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* save lincom values in generated variable
		lincom `var'
		replace varName = "`var'" 		if _n == `x'
		replace varNum 	= `x'*100 		if _n == `x'
		replace coef 	= `r(estimate)' if _n == `x'
		replace sE 		= `r(se)' 		if _n == `x'
		replace pValue 	= `r(p)' 		if _n == `x'
		replace loop 	= `l'			if _n == `x'
	* replace iteration variable
		local x = `x' + 1
	}
* drop randomly generated variable
drop random_Y

}

* generate variables for plot legend:
foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %3.2f meanCoef
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10
	
gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 			if variable == 1
	replace coefficient = `meanCoefreal_10_20' 				if variable == 2
	replace coefficient = `meanCoefreal_20_30' 				if variable == 3
	replace coefficient = `meanCoefreal_30_40' 				if variable == 4
	replace coefficient = `meanCoefreal_40_50' 				if variable == 5
	replace coefficient = 0 								if variable == 6
	replace coefficient = `meanCoefreal_60_70' 				if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 				if variable == 8
	replace coefficient = `meanCoefreal_80_90' 				if variable == 9
	replace coefficient = `meanCoefreal_over_90' 			if variable == 10

gen p25 = .
	replace p25 = `p25real_under_10' 		if variable == 1
	replace p25 = `p25real_10_20' 			if variable == 2
	replace p25 = `p25real_20_30' 			if variable == 3
	replace p25 = `p25real_30_40' 			if variable == 4
	replace p25 = `p25real_40_50' 			if variable == 5
	replace p25 = `p25real_60_70' 			if variable == 7
	replace p25 = `p25real_70_80' 			if variable == 8
	replace p25 = `p25real_80_90' 			if variable == 9
	replace p25 = `p25real_over_90' 		if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 				if variable == 1
	replace p975 = `p975real_10_20' 				if variable == 2
	replace p975 = `p975real_20_30' 				if variable == 3
	replace p975 = `p975real_30_40' 				if variable == 4
	replace p975 = `p975real_40_50' 				if variable == 5
	replace p975 = `p975real_60_70' 				if variable == 7
	replace p975 = `p975real_70_80' 				if variable == 8
	replace p975 = `p975real_80_90' 				if variable == 9
	replace p975 = `p975real_over_90' 				if variable == 10

sort variable

* plot results by themselves 
graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation2_SchlenkerPRISM_F.pdf", replace
