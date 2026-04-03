/*******************************************************************************
AUTHOR: Cristine von Dessauer
DATE: February 2025
ACTION: Simulation 1: outcome and temperature variable are simulated 
in binned temperature regressions with modern schemed graphs and xaxis that moves
from -10 to 35

UPDATE: Change everything to Fahrenheit
*******************************************************************************/

clear all
set more off
global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

********************************************************************************
** LOAD DATASETS AND SET WORKING DIRECTORY
********************************************************************************

* set working directory

/* cd "/Users/NIne/Library/CloudStorage/Dropbox/Research/Ben Olken/Temperature and Research/" */
log using "${path}Haru/log/sim1.txt", text replace
use "${path}DTA_US/countyLevel_USPanel_1970_2019_v2.dta", clear

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
	import delimited "${path}Haru/data/county_centroid.csv", clear
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

* transform baseline temperature to Fahrenheit
replace baselinePeriodTemp = (baselinePeriodTemp * 9/5) + 32

********************************************************************************
** 3.1) MC SIMULATION 1: TEMPERATURE AND OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP)
********************************************************************************
/*
* keep relevant variables
keep year fips baselinePeriodTemp stateCode varName loop coef sE varNum pValue

** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius (i.e., 9/5 degree Fahrenheit)
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(year fips)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay*

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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' 		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


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
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-10 25)) ylabel(-10(5)25)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_F.pdf", replace

* store results for combined plot
rename variable 	variableNoSolution
rename coefficient 	coefficientNoSolution
rename p25 			p25NoSolution
rename p975 		p975NoSolution
*/

********************************************************************************
** 3.2) MC SIMULATION 1: TEMPERATURE AND OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - HOMOGENEOUS TREND)
********************************************************************************
/*
** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = year + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(year fips)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay*

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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' 		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 		if variable == 2
	replace p25 = `p25real_20_30' 		if variable == 3
	replace p25 = `p25real_30_40' 		if variable == 4
	replace p25 = `p25real_40_50' 		if variable == 5
	replace p25 = `p25real_60_70' 		if variable == 7
	replace p25 = `p25real_70_80' 		if variable == 8
	replace p25 = `p25real_80_90' 		if variable == 9
	replace p25 = `p25real_over_90' 	if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red))
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_homogeneousTrend_F.pdf", replace

* store results for combined plot
rename variable 	variableNoSolutionH
rename coefficient 	coefficientNoSolutionH
rename p25 			p25NoSolutionH
rename p975 		p975NoSolutionH

*/

********************************************************************************
** 4) MC SIMULATION 1: TEMPERATURE AND OUTCOME SIMULATIONS (NEGATIVE RELATIONSHIP)
********************************************************************************
/*
** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = - year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(year fips)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay*

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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20'		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 		if variable == 2
	replace p25 = `p25real_20_30' 		if variable == 3
	replace p25 = `p25real_30_40' 		if variable == 4
	replace p25 = `p25real_40_50' 		if variable == 5
	replace p25 = `p25real_60_70' 		if variable == 7
	replace p25 = `p25real_70_80' 		if variable == 8
	replace p25 = `p25real_80_90' 		if variable == 9
	replace p25 = `p25real_over_90' 	if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) 
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_negativeTrend_F.pdf", replace

* store results for combined plot
rename variable 	variableNoSolutionN
rename coefficient 	coefficientNoSolutionN
rename p25 			p25NoSolutionN
rename p975 		p975NoSolutionN

*/

********************************************************************************
** 5.1) MC SIMULATION: TEMPERATURE AND OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - WITH SOLUTION)
********************************************************************************

** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* create controls based on normal distributions
	gen exp_under_10 		= 365* (normal((10-simYearlyTemp)/9))
	gen exp_10_20 			= 365* (normal((20-simYearlyTemp)/9)  - normal((10-simYearlyTemp)/9))
	gen exp_20_30 			= 365* (normal((30-simYearlyTemp)/9)  - normal((20-simYearlyTemp)/9))
	gen exp_30_40 			= 365* (normal((40-simYearlyTemp)/9)  - normal((30-simYearlyTemp)/9))
	gen exp_40_50  			= 365* (normal((50-simYearlyTemp)/9) - normal((40-simYearlyTemp)/9))
	gen exp_50_60  			= 365* (normal((60-simYearlyTemp)/9) - normal((50-simYearlyTemp)/9))
	gen exp_60_70  			= 365* (normal((70-simYearlyTemp)/9) - normal((60-simYearlyTemp)/9))
	gen exp_70_80  			= 365* (normal((80-simYearlyTemp)/9) - normal((70-simYearlyTemp)/9))
	gen exp_80_90  			= 365* (normal((90-simYearlyTemp)/9) - normal((80-simYearlyTemp)/9))
	gen exp_over_90 		= 365* (1 - normal((90-simYearlyTemp)/9))

	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_over_90 exp_under_10 exp_over_90, absorb(year fips) // real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_60_70 exp_70_80 exp_80_90 

	* save variables
	foreach var in real_under_10 real_over_90{ //real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90
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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay* exp*
 
}

* generate variables for plot legend:
foreach var in real_under_10 real_over_90{ //real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 
	
	* coefficients by group
	gen meanCoef = coef
	replace meanCoef = . if varName != "`var'"
	_pctile meanCoef, nq(1000)
	local p25`var' = `r(r25)'
	local p975`var' = `r(r975)'
	ereplace meanCoef = mean(meanCoef)
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	/* replace coefficient = `meanCoefreal_10_20' 		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9 */
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	/* replace p25 = `p25real_10_20' 		if variable == 2
	replace p25 = `p25real_20_30' 		if variable == 3
	replace p25 = `p25real_30_40' 		if variable == 4
	replace p25 = `p25real_40_50' 		if variable == 5
	replace p25 = `p25real_60_70' 		if variable == 7
	replace p25 = `p25real_70_80' 		if variable == 8
	replace p25 = `p25real_80_90' 		if variable == 9 */
	replace p25 = `p25real_over_90' 	if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	/* replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9 */
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-10 25)) ylabel(-10(5)25)
qui graph export "${output}sim1/era5_F_naive/simulation1_FipsYearFE_Solution_ext.pdf", replace

* store results for combined plot
rename variable 	variableSolution
rename coefficient 	coefficientSolution
rename p25 			p25Solution
rename p975 		p975Solution

exit
*/

********************************************************************************
** 5.2) MC SIMULATION: TEMPERATURE AND OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - WITH LINEAR TREND)
********************************************************************************
* keep relevant variables
keep year fips baselinePeriodTemp stateCode varName loop coef sE varNum pValue

** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius (i.e., 9/5 degree Fahrenheit)
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(year fips fips#c.year)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay*

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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' 		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


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
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-10 25)) ylabel(-10(5)25)

* store results for combined plot
rename variable 	variableLinearTrend
rename coefficient 	coefficientLinearTrend
rename p25 			p25LinearTrend
rename p975 		p975LinearTrend
*/

********************************************************************************
** 6) MC SIMULATION 1: TEMPERATURE AND OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - REAL EFFECT)
********************************************************************************
/*
** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`stdDev') + 50*real_under_10 + 50*real_over_90

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(year fips)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay*

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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' 		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 		if variable == 2
	replace p25 = `p25real_20_30' 		if variable == 3
	replace p25 = `p25real_30_40' 		if variable == 4
	replace p25 = `p25real_40_50' 		if variable == 5
	replace p25 = `p25real_60_70' 		if variable == 7
	replace p25 = `p25real_70_80' 		if variable == 8
	replace p25 = `p25real_80_90' 		if variable == 9
	replace p25 = `p25real_over_90' 	if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5

	replace p975 = `p975real_60_70' 	if variable == 7
	replace p975 = `p975real_70_80' 	if variable == 8
	replace p975 = `p975real_80_90' 	if variable == 9
	replace p975 = `p975real_over_90' 	if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-5 30)) ylabel(-5(5)30)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_realEffect.pdf", replace

* store results for combined plot
rename variable 	variableNoSolutionRealE
rename coefficient 	coefficientNoSolutionRealE
rename p25 			p25NoSolutionRealE
rename p975 		p975NoSolutionRealE

*/

********************************************************************************
** 7) MC SIMULATION 1: TEMPERATURE AND OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - REAL EFFECT - WITH SOLUTION)
********************************************************************************
/*
** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* create controls based on normal distributions
	gen exp_under_10 		= 365* (normal((10-simYearlyTemp)/9))
	gen exp_10_20 			= 365* (normal((20-simYearlyTemp)/9)  - normal((10-simYearlyTemp)/9))
	gen exp_20_30 			= 365* (normal((30-simYearlyTemp)/9)  - normal((20-simYearlyTemp)/9))
	gen exp_30_40 			= 365* (normal((40-simYearlyTemp)/9)  - normal((30-simYearlyTemp)/9))
	gen exp_40_50  			= 365* (normal((50-simYearlyTemp)/9) - normal((40-simYearlyTemp)/9))
	gen exp_50_60  			= 365* (normal((60-simYearlyTemp)/9) - normal((50-simYearlyTemp)/9))
	gen exp_60_70  			= 365* (normal((70-simYearlyTemp)/9) - normal((60-simYearlyTemp)/9))
	gen exp_70_80  			= 365* (normal((80-simYearlyTemp)/9) - normal((70-simYearlyTemp)/9))
	gen exp_80_90  			= 365* (normal((90-simYearlyTemp)/9) - normal((80-simYearlyTemp)/9))
	gen exp_over_90 		= 365* (1 - normal((90-simYearlyTemp)/9))

	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`stdDev') + 50*real_under_10 + 50*real_over_90

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(year fips)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay* exp*
 
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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' 		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 		if variable == 2
	replace p25 = `p25real_20_30' 		if variable == 3
	replace p25 = `p25real_30_40' 		if variable == 4
	replace p25 = `p25real_40_50' 		if variable == 5
	replace p25 = `p25real_60_70' 		if variable == 7
	replace p25 = `p25real_70_80' 		if variable == 8
	replace p25 = `p25real_80_90' 		if variable == 9
	replace p25 = `p25real_over_90' 	if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-5 30)) ylabel(-5(5)30)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_Solution_realEffect.pdf", replace

* store results for combined plot
rename variable 	variableSolutionRealE
rename coefficient 	coefficientSolutionRealE
rename p25 			p25SolutionRealE
rename p975 		p975SolutionRealE
*/

********************************************************************************
** 8) MC SIMULATION 1: QUADRATIC TEMPERATURE AND QUADRATIC OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP)
********************************************************************************
/*
** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables
	gen tempInPeriod1 = baselinePeriodTemp if year == 1
	bysort fips: ereplace tempInPeriod1 = mean(tempInPeriod1)
		
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = (9/(5*50))^2 * year^2 + tempInPeriod1 if year > 1

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = 10 * year * year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = 20 * year * year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(year fips)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay* tempInPeriod1

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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20'	 	if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 		if variable == 2
	replace p25 = `p25real_20_30' 		if variable == 3
	replace p25 = `p25real_30_40' 		if variable == 4
	replace p25 = `p25real_40_50' 		if variable == 5
	replace p25 = `p25real_60_70' 		if variable == 7
	replace p25 = `p25real_70_80' 		if variable == 8
	replace p25 = `p25real_80_90' 		if variable == 9
	replace p25 = `p25real_over_90' 	if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-10000 25000)) ylabel(-10000(5000)25000)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_QuadTempOutcome.pdf", replace

* store results for combined plot
rename variable 	variableNoSolutionQTO
rename coefficient 	coefficientNoSolutionQTO
rename p25 			p25NoSolutionQTO
rename p975 		p975NoSolutionQTO

*/

********************************************************************************
** 9)  MC SIMULATION 1: QUADRATIC TEMPERATURE AND QUADRATIC OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - LINEAR TREND)
********************************************************************************
/*
** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables
	gen tempInPeriod1 = baselinePeriodTemp if year == 1
	bysort fips: ereplace tempInPeriod1 = mean(tempInPeriod1)
		
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = (9/(5*50))^2 * year^2 + tempInPeriod1 if year > 1

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = 10 * year * year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = 20 * year * year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(year fips fips#c.year)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay* tempInPeriod1

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
	local meanCoef`var': di %9.3f meanCoef
		
	* drop variables
	drop meanCoef

}

* graph evolution of coefficients
gen variable = _n
	replace variable = . if variable > 10

gen coefficient = .
	replace coefficient = `meanCoefreal_under_10' 	if variable == 1
	replace coefficient = `meanCoefreal_10_20' 		if variable == 2
	replace coefficient = `meanCoefreal_20_30' 		if variable == 3
	replace coefficient = `meanCoefreal_30_40' 		if variable == 4
	replace coefficient = `meanCoefreal_40_50' 		if variable == 5
	replace coefficient = 0 						if variable == 6
	replace coefficient = `meanCoefreal_60_70' 		if variable == 7 
	replace coefficient = `meanCoefreal_70_80' 		if variable == 8
	replace coefficient = `meanCoefreal_80_90' 		if variable == 9
	replace coefficient = `meanCoefreal_over_90' 	if variable == 10


gen p25 = .
	replace p25 = `p25real_under_10' 	if variable == 1
	replace p25 = `p25real_10_20' 		if variable == 2
	replace p25 = `p25real_20_30' 		if variable == 3
	replace p25 = `p25real_30_40' 		if variable == 4
	replace p25 = `p25real_40_50' 		if variable == 5
	replace p25 = `p25real_60_70' 		if variable == 7
	replace p25 = `p25real_70_80' 		if variable == 8
	replace p25 = `p25real_80_90' 		if variable == 9
	replace p25 = `p25real_over_90' 	if variable == 10
	
gen p975 = .
	replace p975 = `p975real_under_10' 		if variable == 1
	replace p975 = `p975real_10_20' 		if variable == 2
	replace p975 = `p975real_20_30' 		if variable == 3
	replace p975 = `p975real_30_40' 		if variable == 4
	replace p975 = `p975real_40_50' 		if variable == 5
	replace p975 = `p975real_60_70' 		if variable == 7
	replace p975 = `p975real_70_80' 		if variable == 8
	replace p975 = `p975real_80_90' 		if variable == 9
	replace p975 = `p975real_over_90' 		if variable == 10

sort variable

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-10000 25000)) ylabel(-10000(5000)25000)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_QuadTempOutcome_LinearTrend.pdf", replace

* store results for combined plot
rename variable 	variableLinearTrendQTO
rename coefficient 	coefficientLinearTrendQTO
rename p25 			p25LinearTrendQTO
rename p975 		p975LinearTrendQTO

*/

********************************************************************************
** 10) MC SIMULATION 1: QUADRATIC TEMPERATURE AND QUADRATIC OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - SOLUTION)
********************************************************************************
/*
** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables
	gen tempInPeriod1 = baselinePeriodTemp if year == 1
	bysort fips: ereplace tempInPeriod1 = mean(tempInPeriod1)
		
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = (9/(5*50))^2 * year^2 + tempInPeriod1 if year > 1

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" 	if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 		if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 		if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 		if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 		if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 		if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 		if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 		if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 		if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 		if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* create controls based on normal distributions
	gen exp_under_10 		= 365* (normal((10-simYearlyTemp)/9))
	gen exp_10_20 			= 365* (normal((20-simYearlyTemp)/9)  - normal((10-simYearlyTemp)/9))
	gen exp_20_30 			= 365* (normal((30-simYearlyTemp)/9)  - normal((20-simYearlyTemp)/9))
	gen exp_30_40 			= 365* (normal((40-simYearlyTemp)/9)  - normal((30-simYearlyTemp)/9))
	gen exp_40_50  			= 365* (normal((50-simYearlyTemp)/9) - normal((40-simYearlyTemp)/9))
	gen exp_50_60  			= 365* (normal((60-simYearlyTemp)/9) - normal((50-simYearlyTemp)/9))
	gen exp_60_70  			= 365* (normal((70-simYearlyTemp)/9) - normal((60-simYearlyTemp)/9))
	gen exp_70_80  			= 365* (normal((80-simYearlyTemp)/9) - normal((70-simYearlyTemp)/9))
	gen exp_80_90  			= 365* (normal((90-simYearlyTemp)/9) - normal((80-simYearlyTemp)/9))
	gen exp_over_90 		= 365* (1 - normal((90-simYearlyTemp)/9))

	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = 10 * year * year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = 20 * year * year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_60_70 exp_70_80 exp_80_90 exp_over_90, absorb(year fips)

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay* exp* tempInPeriod1
 
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
	local meanCoef`var': di %9.3f meanCoef
		
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
	replace coefficient = `meanCoefreal_70_80' 					if variable == 8
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

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-10000 25000)) ylabel(-10000(5000)25000)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_QuadTempOutcome_Solution.pdf", replace

* store results for combined plot
rename variable 	variableSolutionQTO
rename coefficient 	coefficientSolutionQTO
rename p25 			p25SolutionQTO
rename p975 		p975SolutionQTO

*/

********************************************************************************
** SIMULATION 1: COMBINED GRAPHS COMPARING SOLUTION METHODS
********************************************************************************

* (1.1) Simulation 1: no solution vs solution: linear trend in outcome

replace variableNoSolution = variableNoSolution - 0.1
replace variableSolution = variableSolution + 0.1
	
	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientSolution variableSolution, color("155 52 58")) (rcap p25Solution p975Solution variableSolution, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "With counterfactual correction") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_Joint_F.pdf", replace

* (1.2) Simulation 1: no solution vs solution: linear trend in outcome

replace variableLinearTrend = variableLinearTrend + 0.1
	
	graph tw (scatter coefficientNoSolution variableNoSolution, color("31 88 137")) (rcap p25NoSolution p975NoSolution variableNoSolution, color("31 88 137")) (scatter coefficientLinearTrend variableLinearTrend, color("155 52 58")) (rcap p25LinearTrend p975LinearTrend variableLinearTrend, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "County linear trend") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_LinearTrend_Joint_F.pdf", replace

* (2.1) Simulation 1: no solution vs solution: quad trend in outcome 

replace variableNoSolutionQTO = variableNoSolutionQTO - 0.1
replace variableSolutionQTO = variableSolutionQTO + 0.1
	
	graph tw (scatter coefficientNoSolutionQTO variableNoSolutionQTO, color("31 88 137")) (rcap p25NoSolutionQTO p975NoSolutionQTO variableNoSolutionQTO, color("31 88 137")) (scatter coefficientSolutionQTO variableSolutionQTO, color("155 52 58")) (rcap p25SolutionQTO p975SolutionQTO variableSolutionQTO, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "With counterfactual correction") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_QuadTempOutcome_Joint_F.pdf", replace

* (2.2) Simulation 1: no solution vs linear trend: quad trend in outcome

replace variableLinearTrendQTO = variableLinearTrendQTO + 0.1
	
	graph tw (scatter coefficientNoSolutionQTO variableNoSolutionQTO, color("31 88 137")) (rcap p25NoSolutionQTO p975NoSolutionQTO variableNoSolutionQTO, color("31 88 137")) (scatter coefficientLinearTrendQTO variableLinearTrendQTO, color("155 52 58")) (rcap p25LinearTrendQTO p975LinearTrendQTO variableLinearTrendQTO, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "County linear trend") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_QuadTempOutcome_LinearTrend_Joint_F.pdf", replace

* (2.3) Simulation 1: linear trend vs solution: quad trend in outcome

	graph tw (scatter coefficientLinearTrendQTO variableLinearTrendQTO, color("31 88 137")) (rcap p25LinearTrendQTO p975LinearTrendQTO variableLinearTrendQTO, color("31 88 137")) (scatter coefficientSolutionQTO variableSolutionQTO, color("155 52 58")) (rcap p25SolutionQTO p975SolutionQTO variableSolutionQTO, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "County linear trend" 3 "With counterfactual correction") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_QuadTempOutcome_LinearTrendVsSolution_F.pdf", replace

* (3) Simulation 1: no solution vs solution: real effect in outcome

replace variableNoSolutionRealE = variableNoSolutionRealE - 0.1
replace variableSolutionRealE = variableSolutionRealE + 0.1

	graph tw (scatter coefficientNoSolutionRealE variableNoSolutionRealE, color("31 88 137")) (rcap p25NoSolutionRealE p975NoSolutionRealE variableNoSolutionRealE, color("31 88 137")) (scatter coefficientSolutionRealE variableSolutionRealE, color("155 52 58")) (rcap p25SolutionRealE p975SolutionRealE variableSolutionRealE, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(, angle(h)) legend(order(1 "No correction" 3 "With counterfactual correction") position(6) rows(1))
	qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_FipsYearFE_RealEffect_Joint_F.pdf", replace


	
*/

********************************************************************************
** 11) MC SIMULATION 1: TEMP AND OUTCOME SIMULATIONS (POSITIVE RELATIONSHIP - SOLUTION - NO YEAR NOR FIPS FE)
********************************************************************************
/*
preserve

* keep relevant variables
keep year fips baselinePeriodTemp stateCode varName loop coef sE varNum pValue

** for this simulation, we simulate both temperature and outcome variables
* between 1970 and 2019 the avg yearly temp increased 1 degree celsius
	
xtset fips year

* set iteration variable
local x = 1

* simulate temperature and outcome variable 100 times 
forvalues l = 1/100{

	* simulate temperature variables that increases by 9/(5*50) every year
	gen simYearlyTemp = baselinePeriodTemp if year == 1
	bysort fips: replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

	* the standard deviation of baseline temp is 9, we fix that for our simulation
	* we sample 365 daily temperatures centered in each fips mean with std dev of 5
	forvalues d = 1/365{
		gen tempDay`d' = rnormal(simYearlyTemp,9)
	}

	* we classify tempDays into bins
	forvalues d = 1/365{
		gen binDay`d' = ""
			replace binDay`d' = "real_under_10" if tempDay`d' < 10
			replace binDay`d' = "real_10_20" 	if tempDay`d' < 20 	& tempDay`d' >= 10
			replace binDay`d' = "real_20_30" 	if tempDay`d' < 30 	& tempDay`d' >= 20
			replace binDay`d' = "real_30_40" 	if tempDay`d' < 40 	& tempDay`d' >= 30
			replace binDay`d' = "real_40_50" 	if tempDay`d' < 50 	& tempDay`d' >= 40
			replace binDay`d' = "real_50_60" 	if tempDay`d' < 60 	& tempDay`d' >= 50
			replace binDay`d' = "real_60_70" 	if tempDay`d' < 70 	& tempDay`d' >= 60
			replace binDay`d' = "real_70_80" 	if tempDay`d' < 80 	& tempDay`d' >= 70
			replace binDay`d' = "real_80_90" 	if tempDay`d' < 90 	& tempDay`d' >= 80
			replace binDay`d' = "real_over_90" 	if tempDay`d' >= 90

	}

	* create bin variables	
	foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90{
		gen `var' = 0
		* count number of days in each year in each bin
		forvalues d = 1/365{
			replace `var' = `var' + 1 if binDay`d' == "`var'"
		}
	}
		
	* create controls based on normal distributions
	gen exp_under_10 		= 365* (normal((10-simYearlyTemp)/9))
	gen exp_10_20 	= 365* (normal((20-simYearlyTemp)/9)  - normal((10-simYearlyTemp)/9))
	gen exp_20_30 		= 365* (normal((30-simYearlyTemp)/9)  - normal((20-simYearlyTemp)/9))
	gen exp_30_40 		= 365* (normal((40-simYearlyTemp)/9)  - normal((30-simYearlyTemp)/9))
	gen exp_40_50  	= 365* (normal((50-simYearlyTemp)/9) - normal((40-simYearlyTemp)/9))
	gen exp_50_60  	= 365* (normal((60-simYearlyTemp)/9) - normal((50-simYearlyTemp)/9))
	gen exp_60_70  	= 365* (normal((70-simYearlyTemp)/9) - normal((60-simYearlyTemp)/9))
	gen exp_70_80  	= 365* (normal((80-simYearlyTemp)/9) - normal((70-simYearlyTemp)/9))
	gen exp_80_90  	= 365* (normal((90-simYearlyTemp)/9) - normal((80-simYearlyTemp)/9))
	gen exp_over_90 		= 365* (1 - normal((90-simYearlyTemp)/9))

	* extract std deviation of otucome variable to calibrate noise variable
	gen temp = year * baselinePeriodTemp
	sum temp
	local stdDev = 2*`r(sd)'
	drop temp
	
	* random variable with mean 0 and variance v^2 
	gen random_Y = year * baselinePeriodTemp + rnormal(0,`stdDev')

	* regression with county and year fixed effects
	reg random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 exp_under_10 exp_10_20 exp_20_30 exp_30_40 exp_40_50 exp_60_70 exp_70_80 exp_80_90 exp_over_90

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
drop random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_50_60 real_60_70 real_70_80 real_80_90 real_over_90 simYearlyTemp tempDay* binDay* expected*
 
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
	local meanCoef`var': di %9.3f meanCoef
		
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
	replace coefficient = `meanCoefreal_70_80' 					if variable == 8
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

graph tw (scatter coefficient variable) (rcap p25 p975 variable), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) //yscale(range(-10 25)) ylabel(-10(5)25)
qui graph export "Panel (ERA Land + WM)/countyLevel/Figures/simulation1_NoFipsYearFE_Solution.pdf", replace

drop variable coefficient p25 p975 
restore

*/
