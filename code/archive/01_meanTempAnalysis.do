/*******************************************************************************
AUTHOR: Cristine von Dessauer
ACTION: Mean temperature analysis
*******************************************************************************/

clear all
set more off
set scheme modern

********************************************************************************
** LOAD DATASETS AND SET WORKING DIRECTORY
********************************************************************************

* set working directory

cd "/Users/NIne/Library/CloudStorage/Dropbox/Research/Ben Olken/Temperature and Research/"

use "Climate Data/ERA Climate Data/ERA Land Daily/countyLevel_USPanel_1970_2019.dta", clear

* create pre period temperature
gen baselinePeriodTemp = avg_daytime_temp if year <= 1980
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
gen agno = year
sum year
replace year = year - `r(min)' + 1

********************************************************************************
** 1) AVERAGE TEMPERATURE TREND
********************************************************************************

levelsof fips, local(fips)

gen trendFigure = .

foreach f of local fips{
	reg avg_daytime_temp year if fips == `f'
	lincom year
	replace trendFigure = `r(estimate)' if fips == `f'
}

egen tag = tag(fips)

tw (scatter trendFigure baselinePeriodTemp) (lfit trendFigure baselinePeriodTemp) if tag == 1, legend(off)

********************************************************************************
** 2) AVERAGE TEMPERATURE COEFFICIENT
********************************************************************************

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

* gen variable
gen avgT = avg_daytime_temp

* set iteration variable
		local x = 1
		* run regression 1000 times 
		forvalues l = 1/10{
		
			* random variable with mean 0 and variance v^2
			gen random_Y = year * baselinePeriodTemp + rnormal(0,9527)

			* regression
			reghdfe random_Y avgT, absorb(`fe`reg'')

			* save variables
			foreach var in avgT{
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
		foreach var in avgT{
			* coefficients by group
			gen meanCoef = coef
			replace meanCoef = . if varName != "`var'"
			_pctile meanCoef, nq(1000)
			local p25`var' = `r(r25)'
			local p975`var' = `r(r975)'
			ereplace meanCoef = mean(meanCoef)
			local meanCoef`var': di %3.2f meanCoef
				
			* share of statistically significant results by group
			gen statisticallySignificant = (pValue < 0.05) if varName == "`var'"
			egen maxLoop = max(loop)
			replace statisticallySignificant = . if varName != "`var'"
		
			egen significantShare = total(statisticallySignificant)
			replace significantShare = (significantShare / maxLoop) * 100
			local significantShare`var': di %3.0f significantShare
		
			* create dashed line if some coefficients are not different from zero
			sum coef if varName == "`var'"
			if `r(min)' < 0 & `r(max)' > 0{
				local xline`var' "xline(0, lpattern(dash) lcolor(red))"
			}
			else{
				local xline`var' "xline()"
			}
			
			* drop variables
			drop meanCoef statisticallySignificant significantShare maxLoop

		}
		
		* plot graphs
		foreach var in avgT{
		qui hist coef if varName == "`var'", percent ytitle("Percent") xtitle("") ///
		xtitle("Average temperature coefficient") note("Mean = `meanCoef`var'', share of significant coefficients = `significantShare`var''%", size(small)) ///
		ylabel( ,labsize(tiny) angle(h)) xlabel( ,labsize(tiny)) `xline`var''
		}
		
		drop variable coefficient p25 p975 
		