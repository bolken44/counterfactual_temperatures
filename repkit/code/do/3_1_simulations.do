/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: July 2025
ACTION: Runs all simulations.
*******************************************************************************
Set Up
*********************************/
log close _all

args data repkit task
global data "`data'"
global repkit "`repkit'"
global task `task'

do "${repkit}code/do/0_setup.do"
global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/"

log using "${log}3_1_simulations/3_1_simulations_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

display "`c(tmpdir)'"
/*********************************
Parallelize temperature data source and control methods
*********************************/
* Declare which ones
local sources  "era5" // prism_1950 prism_1970 ghcn
local methods  "naive stateyearFE lag3 trends 5year year bayes chebyshev adapt"
local binforms "allbins extreme"

* Count items in each dimension
local n_sources  : word count `sources'
local n_methods  : word count `methods'
local n_binforms : word count `binforms'

* Figure out indices based on task ID (swapped order)
local s_index  = ceil(`task' / (`n_binforms' * `n_methods'))
local temp     = mod(`task'-1, (`n_binforms' * `n_methods'))
local b_index  = ceil((`temp' + 1) / `n_methods')
local m_index  = mod(`task'-1, `n_methods') + 1

* Get the actual values
local source  : word `s_index'  of `sources'
local method  : word `m_index'  of `methods'
local binform : word `b_index'  of `binforms'

* Print to verify
di "Slurm task `task': source=`source', method=`method', binform=`binform'"

* Make save folder
cap mkdir "${simulations}sim1/"
cap mkdir "${simulations}sim2/"
cap mkdir "${simulations}sim3/"

/*********************************
Add average annual temperature -- should be deleted later
*********************************/
* GHCN yearly averages
if "`source'" == "ghcn"{
      use "${weather}ghcn_UScountylevel_1968_2016.dta", clear
      drop if year > 2019 | year < 1970

      gen tmean = (TMAX + TMIN) / 2
      bysort fips year: egen avg_yearly_temp = mean(tmean)
      keep fips year avg_yearly_temp
      duplicates drop
}

* PRISM yearly averages (1950-2019)
if strpos("`source'", "prism") {
      use "${pool}data/appended.dta", clear
      if "`source'" == "prism_1970" {
            drop if year > 2019 | year < 1970
      }
      
      replace tMax = (tMax * 9 / 5) + 32
      bysort fips year: egen avg_yearly_temp = mean(tMax)
      keep fips year avg_yearly_temp
      duplicates drop
}

* ERA 5 yearly averages
if "`source'" == "era5"{
      /* use "${raw}countyLevel_USPanel_1970_2019.dta", clear
            //this uses ERA Land, not ERA 5

      drop if year > 2019 | year < 1970
      keep fips year avg_yearly_temp //avg_yearly_temp uses whole day avg not daytime avg
      replace avg_yearly_temp = (avg_yearly_temp * 9 / 5) + 32
      duplicates drop */

      use "${weather}countyannual_US_1970_2019.dta", clear
}

tempfile `source'_avgtemp
save ``source'_avgtemp', replace

/*********************************
Locals for table
*********************************/
local title_era5 = "ERA 5"
local title_prism_1950 = "PRISM"
local title_prism_1970 = "PRISM (1970-2019)"
local title_ghcn = "GHCN"

local sample_era5 = "The sample period is 1970-2019 for ERA Land 5."
local sample_prism_1950 = "The sample period is 1950-2019 for this version of PRISM."
local sample_prism_1970 = "The sample period is 1970-2019 for this version of PRISM."
local sample_ghcn = "The sample period is 1970-2016 for GHCN."

local title_naive = "No correction"
local title_adapt0 = "No correction (Cold Counties)"
local title_adapt1 = "No correction (Hot Counties)"
local title_stateyearFE = "State-Year Fixed Effects"
local title_lag3 = "With 3 Lags"
local title_trends = "County-Specific Linear Trends"
local title_5year = "County-5 Year Fixed Effects"
local title_year = "Lin. in Year"
local title_bayes = "Lin. in Year + Bayes"
local title_chebyshev = "Chebyshev"

// start of loop
global source = "`source'"
global method = "`method'"

local data_`source'_naive = "`data_`source'_year'"
local data_`source'_adapt0 = "`data_`source'_year'"
local data_`source'_adapt1 = "`data_`source'_year'"
local data_`source'_trends = "`data_`source'_year'"
local data_`source'_stateyearFE = "`data_`source'_year'"
local data_`source'_lag3 = "`data_`source'_year'"
local data_`source'_5year = "`data_`source'_year'"

local row = "`row' \midrule \multirow{8}{*}{`title_`source''}"

/*********************************
Locals
*********************************/
local base_era5 = 1980
local base_prism_1950 = 1960
local base_prism_1970 = 1980
local base_ghcn = 1980

/* local graph_neg1 "yscale(range(-3 1)) ylabel(-3(.5)1)"
local graph_0 "yscale(range(-1 1)) ylabel(-.1(.05).1)"
local graph_1 "yscale(range(-3 5)) ylabel(-3(.5)5)" */

local compare1 = cond(strpos("`method'", "naive") > 0, "none", cond(strpos("`method'", "trends") > 0, "naive trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "naive stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "naive lags, 3", cond(strpos("`method'", "5year") > 0, "naive 5year, county5year year", "naive sim")))))

local compare2 = cond(strpos("`method'", "naive") > 0, "none", cond(strpos("`method'", "trends") > 0, "naive trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "naive stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "naive lags, 3", cond(strpos("`method'", "5year") > 0, "naive 5year, county5year year", cond(strpos("`method'", "adapt") > 0, "naive het, aboveMedian", "naive cftemp")))))) //different from sim 1 compare! cftemp instead of sim

/*********************************
Main script
*********************************/
      * Counterfactual temperature controls
      if "`method'" == "bayes" | "`method'" == "chebyshev" { // "`method'" == "year" |
            /* use "${temperature}`source'_UScounty_cftemp_F_`method'.dta", clear */
            use "${weather}era5_UScounty_1970_2019_cftemp_F_`method'.dta", clear
      }
      * Reduced Form Methods
      else {
            /* use "${temperature}`source'_UScounty_cftemp_F_year.dta", clear */
            use "${weather}era5_UScounty_1970_2019_cftemp_F.dta", clear
      }

      xtset fips year
      drop if year > 2019 | year < 1970

      * Merge average temps
      merge m:1 year fips using ``source'_avgtemp'
      keep if _merge == 3
      drop _merge

      * add state information
      merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
      egen stateCode = group(state)
      drop if state == "AK" | state == "PR" | state == "HI"

      * state-year FE
      egen stateyear = group(state year)

      * create pre period temperature
      gen baselinePeriodTemp = avg_yearly_temp if year <= `base_`source''
      bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

      * adaptation spec
      if strpos("`method'", "adapt") > 0 {
            
            * divide sample into two: above and below pre-period median temperature
            sum baselinePeriodTemp, detail
            local medianPreTemp = `r(p50)'

            gen aboveMedian = baselinePeriodTemp > `medianPreTemp'
      }

      * create numeric variable for year
      gen agno = year
      sum year
      replace year = year - `r(min)' + 1

      * county - 5 year FEs
      gen year_bin5 = floor(year/5)*5
      egen county5year = group(fips year_bin5)

      drop _merge year_bin5 avg_yearly_temp

      /*********************************
      All bins
      *********************************/
      if "`binform'" == "allbins" {

            ********************************* Simulations with simulated temperature data (sim1)
            * Linear trends
            if "`method'" == "naive" {
                  forval slope = -1(1)1 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, `slope') $bins compare(`compare1') fe(fips year) cluster(fips) graph(`graph_`slope'')
                  }
            }
            if  "`method'" == "year" {
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, 1) $bins compare(`compare1') fe(fips year) cluster(fips) graph(`graph_`slope'')

                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(quad, 1) $bins compare(`compare1') fe(fips year) cluster(fips) graph(`graph_`slope'')

                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, 1) $bins compare(`compare1') fe(fips year) cluster(fips) graph(`graph_`slope'') effect(5)
            }
            
            ********************************* Simulations with real temperature data (sim2)
            * Linear trends
            if "`method'" == "naive" { // this is not necessarily, just restricting to what we use in the paper
                  forval slope = -1(1)1 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, `slope') $bins compare(`compare2') fe(fips year) cluster(fips) graph(`graph_`slope'')
                  }
            }
            else {
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) $bins compare(`compare2') fe(fips year) cluster(fips) graph(`graph_1')
            }

            if strpos("`method'", "adapt") <= 0 {
                  * Quadratic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(quad, 1) $bins compare(`compare2') fe(fips year) cluster(fips)

                  * Cubic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(cubic, 1) $bins compare(`compare2') fe(fips year) cluster(fips)

                  * Linear trend, real effect of 5 on both extreme bins
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) $bins compare(`compare2') fe(fips year) cluster(fips) effect(5)
            }
      }

      /*********************************
      Just the extreme bins
      *********************************/
      if "`binform'" == "extreme" {
            
            ********************************* Simulations with real temperature data (sim2)
            * Linear trends + bias table
            cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) $bins compare(`compare2') fe(fips year) cluster(fips) extreme bias

            if strpos("`method'", "adapt") <= 0 {
                  * Quadratic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(quad, 1) $bins compare(`compare2') fe(fips year) cluster(fips) extreme

                  * Cubic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(cubic, 1) $bins compare(`compare2') fe(fips year) cluster(fips) extreme
            }
      }

log close
exit

********************************************************************************
** SIMULATION 2 ADAPTATION
********************************************************************************

foreach source in era5_bayes era5_avgtrend era5_avgtrend_bayes era5_chebyshev { //prism_1950 ghcn era5 era5_bayes era5_avgtrend era5_avgtrend_bayes era5_chebyshev 
      
      * Prepare dataset
      use "`data_`source''", clear

      xtset fips year
      drop if year > 2019 | year < 1970

      * Merge average temps
      merge m:1 year fips using ``source'_avgtemp'
      keep if _merge == 3
      drop _merge

      * add state information
      merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
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
                  foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 {
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
            graph export "${output}sim2/`binform'/`source'/sim2_adaptation_`source'.pdf", replace

            log close
}

********************************************************************************
** SIMULATION 3
********************************************************************************
foreach source in era5 { //prism_1950 ghcn era5

      * Prepare dataset
      use "`data_`source''", clear

      xtset fips year
      drop if year > 2019 | year < 1970

      * Merge average temps
      merge m:1 year fips using ``source'_avgtemp'
      keep if _merge == 3
      drop _merge

      * add state information
      merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
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

}