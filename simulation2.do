/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: April 2025
ACTION: All simulation 2.
*******************************************************************************/

clear all
set more off

ssc install ppmlhdfe
ssc install ereplace

global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

********************************************************************************
** Regressors
********************************************************************************
adopath + "${path}/Haru/cftemp"
run "${path}/Haru/cftemp/cftemp_sim.ado"

********************************************************************************
** ADD WEATHER DATA
********************************************************************************
local data_era5 = "${weather}era5_UScounty_1970_2019_cftemp.dta"
local data_month_era5 = "${weather}era5_monthly_UScounty_1970_2019_cftemp.dta"
local bins_era5 = "binsize(5) lb(-10) ub(35) omit(6)"

local data_era5_F_year = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F_year = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"
local bins_era5_F = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_5year = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F_5year = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"


local data_era5_F_bayes = "${weather}era5_UScounty_1970_2019_cftemp_F_bayes.dta"
local data_month_era5_F_bayes = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_bayes.dta"

local data_era5_F_splines = "${weather}era5_UScounty_1970_2019_cftemp_F_splines.dta"
local data_month_era5_F_splines = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_splines.dta"

local data_era5_F_avgtrend = "${weather}era5_UScounty_1970_2019_cftemp_F_avgtrend.dta"
local data_month_era5_F_avgtrend = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_avgtrend.dta"

local data_era5_F_avgtrend_bayes = "${weather}era5_UScounty_1970_2019_cftemp_F_avgtrend_bayes.dta"
/* local data_month_era5_F_avgtrend_bayes = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_avgtrend_bayes.dta" */

local data_era5_F_chebyshev = "${weather}era5_UScounty_1970_2019_cftemp_F_chebyshev.dta"
local data_month_era5_F_chebyshev = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_chebyshev.dta"

local data_era5_F_aggregate = "${weather}era5_UScounty_1970_2019_cftemp_F_aggregate.dta"
local data_month_era5_F_aggregate = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_aggregate.dta"



local data_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp.dta"
local prcp_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp_prcp.dta"
local data_month_ghcn = "${weather}ghcn_monthly_UScounty_1968_2002_cftemp.dta"
local prcp_month_ghcn = "${weather}ghcn_monthly_UScounty_1968_2002_cftemp_prcp.dta"
local bins_ghcn = "binsize(10) lb(10) ub(90) omit(6)"

local data_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp.dta"
local prcp_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp_prcp.dta"
local data_month_ghcn_ext = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp.dta"
local prcp_month_ghcn_ext = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_prcp.dta"
local bins_ghcn_ext = "binsize(10) lb(10) ub(90) omit(6)"

local data_schlenker = "${weather}schlenker_UScounty_1950_2019_cftemp.dta"
local data_month_schlenker = "${weather}schlenker_UScounty_1950_2019_cftemp.dta"
local bins_schlenker = "binsize(5) lb(-10) ub(35) omit(6)"

local data_schlenker_F = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
local data_month_schlenker_F = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
local bins_schlenker_F = "binsize(10) lb(10) ub(90) omit(6)"

* GHCN yearly averages
/* use "${path}Haru/processed/ghcn_UScountylevel_1968_2016.dta", clear
drop if year > 2019 | year < 1970

gen tmean = (TMAX + TMIN) / 2
bysort fips year: egen avg_yearly_temp = mean(tmean)
keep fips year avg_yearly_temp
duplicates drop

tempfile ghcn_ext_avgtemp
save `ghcn_ext_avgtemp' */

* PRISM yearly averages
/* use "${path}Haru/data/PRISM_Schlenker/appended.dta", clear
drop if year > 2019 | year < 1970

bysort fips year: egen avg_yearly_temp = mean(tMax)
keep fips year avg_yearly_temp
duplicates drop

tempfile schlenker_F_avgtemp
save `schlenker_F_avgtemp'  */

* ERA 5 yearly averages
use "${path}DTA_US/countyLevel_USPanel_1970_2019.dta", clear
      //this uses ERA Land, not ERA 5

drop if year > 2019 | year < 1970
keep fips year avg_yearly_temp //avg_yearly_temp uses whole day avg not daytime avg
/* replace avg_yearly_temp = (avg_yearly_temp * 9 / 5) + 32 */
duplicates drop

tempfile era5_F_avgtemp
save `era5_F_avgtemp'

********************************************************************************
** OUTCOME DATA
********************************************************************************

**** mortality (full panel)
/* preserve 
	use "${outcomes}mortality_countyPanel_19682016.dta", clear

	* construct mortality rates
	foreach var in allAges less1 1_44 45_64 more65{
		gen mortality_`var' = (deaths_`var'/population_`var')*100000
	}
	* keep relevant time period
	keep if inrange(year,1968,2019)
	
	tempfile mortalityByFips
	save `mortalityByFips'
restore */

********************************************************************************
** OTHER DETAILS
********************************************************************************
* set seed
set seed 1642

* add state information
preserve
	import delimited "${path}Haru/data/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

* version details
local compare_none "compare(none) fe(fips year)"
local compare_cftemp "compare(naive cftemp) fe(fips year)"
forval lags = 1(2)5 {
      local compare_lag`lags' "compare(naive lags, `lags') fe(fips year)"
}
local compare_trends "compare(naive trends, fips#c.year) fe(fips year)"
local compare_5year "compare(naive 5year, county5year year) fe(fips year)"
/* local compare_fe "fe(fips year year##stateCode)" */

local graph_neg1 "yscale(range(-3 1)) ylabel(-3(.5)1)"
local graph_0 "yscale(range(-.1 .1)) ylabel(-.1(.05).1)"
local graph_1 "yscale(range(-1.5 3.5)) ylabel(-1.5(.5)3.5)"

********************************************************************************
** RUN
********************************************************************************
foreach source in era5_F { //schlenker_F ghcn_ext 
      
      foreach method in year { // naive trends year year_bayes splines avgtrend avgtrend_bayes chebyshev  era5_F_bayes era5_F_avgtrend era5_F_avgtrend_bayes era5_F_chebyshev

            * Prepare dataset
            use "`data_`source'_`method''", clear

            log using "${path}Haru/log/sim2_`source'_`method'.txt", text replace
            display "Current time: " c(current_date) " " c(current_time)

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

            * county - 5 year FEs
            gen year_bin5 = floor(year/5)*5
            egen county5year = group(fips year_bin5)

            ********************************* Simulations
            * Loop over naive and comparisons
            foreach ver in cftemp { // cftemp none trends lag1 lag3 lag5 fe

                  * Linear trends
                  foreach slope in 1 { //forval slope = -1(1)1
                        local slope_str = cond(`slope' == -1, "neg1", "`slope'")

                        /* cftemp_sim baselinePeriodTemp fips year, simulate(1000) outcome(linear, `slope') `bins_`source'' `compare_`ver'' cluster(fips)
                        cap mkdir "${output}sim2/`source'_`method'/"
                        cap mkdir "${output}sim2/`source'_`method'/`ver'/"
                        graph export "${output}sim2/`source'_`method'/`ver'/sim2_`ver'_lin`slope_str'_`source'_`method'.pdf", replace */

                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) outcome(linear, `slope') `bins_`source'' `compare_`ver'' cluster(fips) effect(5)
                        graph export "${output}sim2/`source'_`method'/`ver'/sim2_`ver'_lin`slope_str'_effect5_`source'_`method'.pdf", replace

                  }

                  * Quadratic trends
                  /* cftemp_sim baselinePeriodTemp fips year, simulate(1000) outcome(quad, 1) `bins_`source'' `compare_`ver'' cluster(fips)
                  /* cap mkdir "${output}sim2/`source'_`method'/`ver'/" */
                  graph export "${output}sim2/`source'_`method'/`ver'/sim2_`ver'_quad_`source'_`method'.pdf", replace */

            }

            log close

      }
}

exit

********************************************************************************
** SIMULATION 1 (does not work right now -- the code in bias_table.do works)
********************************************************************************
log using "${path}Haru/log/sim1.txt", text replace
use "${path}DTA_US/countyLevel_USPanel_1970_2019_v2.dta", clear

xtset fips year
drop if year > 2019 | year < 1970

* Merge average temps
merge m:1 year fips using `era5_F_avgtemp'
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
replace baselinePeriodTemp = (baselinePeriodTemp * 9/5) + 32

* create numeric variable for year
gen agno = year
sum year
replace year = year - `r(min)' + 1 //why +1? Ask Cristine

cftemp_sim baselinePeriodTemp fips year, simulate(10) option(1) outcome(linear, 1) binsize(10) lb(10) ub(90) omit(6) compare(naive cftemp) fe(fips year) cluster(fips) //extreme
cap mkdir "${output}sim1/`source'_`method'/"
cap mkdir "${output}sim1/`source'_`method'/cftemp/"
graph export "${output}sim1/`source'_`method'/cftemp/sim1_`ver'_lin1_`source'_`method'.pdf", replace
exit

********************************************************************************
** SIMULATION 2 ADAPTATION
********************************************************************************

foreach source in era5_F_bayes era5_F_avgtrend era5_F_avgtrend_bayes era5_F_chebyshev { //schlenker_F ghcn_ext era5_F era5_F_bayes era5_F_avgtrend era5_F_avgtrend_bayes era5_F_chebyshev 

      log using "${path}Haru/log/sim2_`source'.txt", text replace
      display "Current time: " c(current_date) " " c(current_time)
      
      * Prepare dataset
      use "`data_`source''", clear

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
      sum year
      replace year = year - `r(min)' + 1

      * divide sample into two: above and below pre temp median
      sum baselinePeriodTemp, detail
      local medianPreTemp = `r(p50)'

      gen aboveMedian = baselinePeriodTemp > `medianPreTemp'

      * loop through both types of datasets
      foreach value in 0 1{

            preserve

            keep if aboveMedian == `value'
            
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
            forvalues l = 1/100{

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
            graph export "${output}sim2/`source'/sim2_adaptation_`source'.pdf", replace

            log close
}

exit
********************************************************************************
** SIMULATION 3
********************************************************************************
foreach source in era5_F { //schlenker_F ghcn_ext era5_F

      * Prepare dataset
      use "`data_`source''", clear

      log using "${path}Haru/log/sim3_`source'.txt", text replace
      display "Current time: " c(current_date) " " c(current_time)

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
      sum year
      replace year = year - `r(min)' + 1

      foreach outcome in mortality_more65 { //violentCrime nonViolentCrime logCornOutput logWheatOutput logSoyOutput

            preserve

            merge 1:1 fips year using `mortalityByFips', keep(match master) nogen
            keep if year <= 2002

                  * generate variables to fill
                  gen varName = ""
                  gen loop = .
                  gen coef = .
                  gen sE = .
                  gen varNum = .
                  gen pValue = .
                  
                  **** step 1: run regression and store fixed effect coefficients
                  gen constant_1 = .

                  reghdfe `outcome', absorb(fipsFE = fips yearFE = year alphaCoefficient = i.fips#c.year) residual(epsilon_1)
                  * extract constant of regression
                  replace constant_1 = _b[_cons]
                  * assign fips FE for all rows
                  bysort fips: ereplace fipsFE = mean(fipsFE)
                  * assign alpha coefficient to all 
                  rename alphaCoefficientSlope1 alphaCoefficient
                  bysort fips: ereplace alphaCoefficient = mean(alphaCoefficient)
                        
                  **** step 2: run regression over estimated trends

                  gen betaCoefficient = .
                  gen constant_2 = .

                  egen tag = tag(fips)
                  
                  * run regression once for each fips 
                  reg alphaCoefficient baselinePeriodTemp if tag == 1
                  * extract coefficient
                  replace betaCoefficient = _b[baselinePeriodTemp]
                  replace constant_2 = _b[_cons]
                  * extract residual
                  predict epsilon_2, residuals

                  **** step 3: create standard error variables for synthetic outcome

                  sum epsilon_1
                        local sdEpsilon_1 = `r(sd)'	
                  sum epsilon_2
                        local sdEpsilon_2 = `r(sd)'

                  **** step 4:  we loop over the different regression versions and simulate

                  * set iteration variable
                  local x = 1
                  
                  * run regression 1000 times 
                  forvalues l = 1/1000{
                        
                        * random variable based on results obtained above 
                        gen random_Y = fipsFE + constant_1 + (constant_2 + betaCoefficient * baselinePeriodTemp) * year + rnormal(0,`sdEpsilon_1') // BETA METHOD
            //		gen random_Y = fipsFE + constant_1 + alphaCoefficient * year + rnormal(0,`sdEpsilon_1') // ALPHA METHOD

                        * run regression
                        qui reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)
                  
                        * save variables
                        foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90{
                              * save lincom values in generated variable
                                    qui lincom `var'
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
                              local meanCoef`var': di %5.4f meanCoef
                                                      
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
                  graph tw (scatter coefficient variable, color("31 88 137")) (rcap p25 p975 variable, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small)) xtitle("") legend(order(2 "2.5 - 97.5 pctile") position(6)) yline(0, lpattern(dash) lcolor(red)) ylabel(-2(2)8, angle(h))
                  cap mkdir "${output}sim3/`source'/"
                  graph export "${output}sim3/`source'/sim3_`outcome'_`source'.pdf", replace

                  drop variable coefficient p25 p975 
                  
            restore

      }

      log close
}