/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: May 2025
ACTION: Runs
- simulation 2 under non-standard specifications
- simulations 3
*******************************************************************************
Set Up
*********************************/
args data repkit task
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"
global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/"

log using "${log}3_3_other_sim/3_3_other_sim_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Parallelize temperature data source and control methods
*********************************/
local combo1 "era5 state"
local combo2 "era5 decade"
local combo3 "era5 kdd"
local combo4 "era5 poly4"
local combo5 "era5 magnitude"

local source = word("`combo`task''", 1)
local method = word("`combo`task''", 2)

* Print to verify
di "Slurm task `task': source=`source', method=`method'"

* For sim 3, parallelize the outcome variable
local outcomes "more65 violent nonViolent corn soy wheat" //allAges less1 1_44 45_64 more65
if `task' > 5 {
      local j = `task' - 5
      local outcome = word("`outcomes'", `j')
      di "Outcome: `outcome'"
}

/*********************************
* Add outcome variables
*********************************/
*** crime (month level regressions)
if "`outcome'" == "violent" | "`outcome'" == "nonViolent" {
      use "${outcomes}Ranson_2012.dta", clear

      keep if year >= 1970
      keep month pop rate_allcrimes rate_murder rate_rape rate_robbery rate_assaultaggr rate_larceny state county year
	
      * collapse to year level
	collapse (sum) rate_allcrimes rate_murder rate_rape rate_robbery rate_assaultaggr rate_larceny, by(county year)
      
      rename county fips
      destring fips, replace
      replace fips = 46102 if fips == 46113

      * generate outcome variable
      /* egen violent = rowtotal(rate_murder rate_rape rate_assaultaggr)
      egen nonViolent = rowtotal(rate_robbery rate_larceny) */
}

*** crops
if "`outcome'" == "corn" | "`outcome'" == "soy" | "`outcome'" == "wheat" {
      use "${outcomes}`outcome'.dta", clear

      destring fips, replace
      rename value `outcome'Output
      gen `outcome' = log(`outcome'Output)
      
      * keep relevant time period
      keep if inrange(year,1970,2019)
}

**** mortality (full panel)
if "`outcome'" == "more65" {
      use "${outcomes}mortality_countyPanel_19682016.dta", clear

      * construct mortality rates
      gen `outcome' = (deaths_`outcome'/population_`outcome')*100000

      * keep relevant time period
      keep if inrange(year,1970,2019) //68-
}

gen agno = year
sum fips
tempfile `outcome'ByFips
save ``outcome'ByFips', replace

/*********************************
Locals
*********************************/
local base_era5 = 1980
local base_prism_1950 = 1960
local base_prism_1970 = 1980
local base_ghcn = 1980

* Sample period start year
local minyear_ghcn = 1968
local minyear_era5_F = 1970

local omit = 55 // for polynomials

global source = "`source'"
global method = "`method'"

* average temperature (delete later)
use "${weather}countyannual_US_1970_2019.dta", clear
/* use "${weather}countyLevel_USPanel_1970_2019_v2.dta", clear  // this is what Cristine used originally
replace avg_yearly_temp = (avg_yearly_temp * 9/5) + 32 */
tempfile `source'_avgtemp
save ``source'_avgtemp', replace

/*********************************
Prepare Dataset
*********************************/
if "`method'" == "state" | "`method'" == "decade" | "`method'" == "magnitude" | `task' > 5 {
      /* use "${temperature}`source'_UScounty_cftemp_F_bin10_year.dta", clear */
      use "${weather}era5_UScounty_1970_2019_cftemp_F.dta", clear
}
else if "`method'" == "poly4" | "`method'" == "kdd" {
      use "${temperature}`source'_UScounty_`method'_F.dta", clear
}

xtset fips year
drop if year > 2019 | year < 1970

* Merge average temps
merge m:1 year fips using ``source'_avgtemp'
assert _merge == 3
drop _merge

* add state information
merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
egen stateCode = group(state)
drop if state == "AK" | state == "PR" | state == "HI"
drop _merge

* create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
gen agno = year
sum year
replace year = year - `r(min)' + 1
xtset fips year

* generate variables to fill
gen varName = ""
gen loop = .
gen coef = .
gen sE = .
gen varNum = .
gen pValue = .

* Save temperature std deviation
gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* set iteration variable
local i = 1 //version
local x = 1 //bin

/*********************************
State level
*********************************/
if "`method'" == "state" {

      * collapse to the state level
      collapse (mean) exp_* real_* baselinePeriodTemp, by(year stateCode)

      cftemp_sim baselinePeriodTemp stateCode year, simulate(1000) option(2) outcome(lin, 1) binsize($binsize) lb($lb) ub($ub) omit($omit) compare(none) fe(stateCode year) cluster(stateCode)
}

/*********************************
Decade level
*********************************/
if "`method'" == "decade" {

      * collapse to the decade level
      gen decade = year/10
      replace decade = floor(decade)

      collapse (sum) exp_* real_* (mean) baselinePeriodTemp, by(decade fips)
            
      cftemp_sim baselinePeriodTemp fips decade, simulate(1000) option(2) outcome(lin, 1) binsize($binsize) lb($lb) ub($ub) omit($omit) compare(none) fe(fips decade) cluster(fips)
}

/*********************************
KDD
*********************************/
if "`method'" == "kdd" {

      forval t = 80(5)95 {

            * Run simulations
            forval l = 1/1000 {

                  * random variable with mean 0 and variance
                  gen random_Y = 1 * year * baselinePeriodTemp + rnormal(0,`oneStdDevValue')

                  * regression
                  reghdfe random_Y kdd`t', absorb(fips year) cluster(fips)

                  * save estimate
                  replace coef = _b[kdd`t'] if _n == `l'

                   * drop randomly generated variables to draw again
                  drop random_Y
            }

            * Take percentile of estimates
            preserve
            drop if coef == .
            
            _pctile coef, nq(1000)
            local p25_kdd`t' = `r(r25)'
            local p975_kdd`t' = `r(r975)'
            local coef_kdd`t' = `r(r500)'
            restore
      }

      * Plot
      clear
      set obs 4
      gen temp = .

      foreach var in coef p25 p975 {
            gen `var' = .
            local i = 1
            forval t = 80(5)95 {
                  replace temp = `t' if _n == `i'
                  replace `var' = ``var'_kdd`t'' if temp == `t'
                  local i = `i' + 1
            }
      }

      *************************** Plotting
      graph twoway ///
            (bar coef temp, barw(1) fcolor("150 170 190") lcolor("150 170 190")) ///
            (rcap p975 p25 temp, color("31 88 137")), ///
            xlabel(, labsize(small) nogrid) ///
            xtitle("") ///
            yline(0, lpattern(dash) lcolor(red)) ///
            ylabel(, angle(h) nogrid) legend(off)
      graph export "${simulations}sim2/sim2_lin1_`source'_`method'_F.pdf", replace
}

/*********************************
Carleton et al (2022) Polynomials
*********************************/
if "`method'" == "poly4" {
      
      forvalues l = 1/1000 {

            * random variable with mean 0 and variance v^2
            gen random_Y = 1 * year * baselinePeriodTemp + rnormal(0,`oneStdDevValue')

            * regression
            reghdfe random_Y temp_poly_*, absorb(fips year) cluster(fips)

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

      drop if preds_`omit' == .

      * generate variables for plot
      forval temp = 5/95 {

            * take percentile of predicted values
            preserve
            drop if preds_`temp' == .

            _pctile preds_`temp', nq(1000)
            local p25_`temp' = `r(r25)'
            local p975_`temp' = `r(r975)'
            local coef_`temp' = `r(r500)'

            restore
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
            xlabel(, labsize(small) nogrid) ///
            xtitle("") ///
            yline(0, lpattern(dash) lcolor(red)) ///
            ylabel(, angle(h) nogrid) legend(off)
      graph export "${simulations}sim2/sim2_lin1_`source'_`method'_F.pdf", replace

}

/*********************************
Simulation Plot by Magnitudes of Outcome Trend
*********************************/
if "`method'" == "magnitude" {
	replace varName = "real_under_10" 		if _n == 1
	replace varName = "real_10_20" 		if _n == 2
	replace varName = "real_20_30" 		if _n == 3
	replace varName = "real_30_40" 		if _n == 4 
	replace varName = "real_40_50"  		if _n == 5
      replace varName = "real_50_60"  		if _n == 6
	replace varName = "real_60_70" 		if _n == 7
	replace varName = "real_70_80"  		if _n == 8
	replace varName = "real_80_90"  		if _n == 9
	replace varName = "real_over_90" 		if _n == 10
      replace varNum = _n if _n <= 10

      forvalues beta = 1(1)100{

            * we run each version of sigma/beta 100 times 
            forvalues l = 1/100 { 
            
                  local slope = `beta'/10000 * `oneStdDevValue'
                  
                  gen random_Y = (`slope' * baselinePeriodTemp) * year + rnormal(0,`oneStdDevValue')
            
                  * run regression
                  reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)
            
                  * save variables
                  gen coef_`l' = .
                  foreach var in real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90 {
                        replace coef_`l' = _b[`var'] if varName == "`var'"
                  }
                  replace coef_`l' = 0 if varName == "real_50_60"

                  * drop created variables
                  drop random_Y 
            }

            * store values
            egen beta_`beta' = rowmean(coef_*)

            * drop created variables
            drop coef_*
      }
      
      * plot
      drop if varName == ""
      local plotDescription = "(line beta_1 varNum, lcolor(gs15))"
      forvalues beta = 2(2)100{
            local plotDescription = "`plotDescription'" + " " + "(line beta_`beta' varNum, lcolor(gs9))"
      }

      graph tw `plotDescription' (line beta_1 varNum, lcolor(red) lwidth(0.5)) (line beta_25 varNum, lcolor(blue) lwidth(0.5)) (line beta_50 varNum, lcolor(green) lwidth(0.5)) (line beta_100 varNum, lcolor(purple) lwidth(0.5)), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small) nogrid) ylabel(, nogrid) xtitle("") yline(0, lpattern(dash)) legend(order(52 "{&beta} = 0.0001 {&sigma}" 53 "{&beta}  = 0.0025 {&sigma}" 54 "{&beta}  = 0.005 {&sigma}" 55 "{&beta}  = 0.01 {&sigma}") pos(6) rows(1) size(medsmall))
      graph export "${simulations}sim2/sim2_lin1_`source'_`method'_F.pdf", replace


      ** replace beta for negative beta
      forvalues b = 1(1)100{
            replace beta_`b' = - beta_`b'
      }

      local plotDescription = "(line beta_1 varNum, lcolor(gs15))"
      forvalues beta = 2(2)100{
            local plotDescription = "`plotDescription'" + " " + "(line beta_`beta' varNum, lcolor(gs9))"
      }

      graph tw `plotDescription' (line beta_1 varNum, lcolor(red) lwidth(0.5)) (line beta_25 varNum, lcolor(blue) lwidth(0.5)) (line beta_50 varNum, lcolor(green) lwidth(0.5)) (line beta_100 varNum, lcolor(purple) lwidth(0.5)), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small) nogrid) ylabel(, nogrid) xtitle("") yline(0, lpattern(dash)) legend(order(52 "{&beta} = -0.0001 {&sigma}" 53 "{&beta}  = -0.0025 {&sigma}" 54 "{&beta}  = -0.005 {&sigma}" 55 "{&beta}  = -0.01 {&sigma}") pos(6) rows(1) size(medsmall))
      graph export "${simulations}sim2/sim2_linneg1_`source'_`method'_F.pdf", replace
}


/*********************************
Simulation 3
*********************************/
if `task' > 5 {

      merge 1:1 fips agno using ``outcome'ByFips'
      drop if _merge == 2
      drop agno

      * generate outcome variable for crime
      if "`outcome'" == "violent" | "`outcome'" == "nonViolent" {
            egen violent = rowtotal(rate_murder rate_rape rate_assaultaggr)
            egen nonViolent = rowtotal(rate_robbery rate_larceny)
      }
      if "`outcome'" == "more65" {
            replace more65 = . if year > 2002
      }

      * gen tag to plot one observation per county
      egen tag = tag(fips)

	************************* outcome trend 
	reghdfe `outcome', absorb(fips year alphaCoefficient = i.fips#c.year)

	* assign alpha coefficient to all 
	rename alphaCoefficientSlope1 alphaCoefficient
	bysort fips: ereplace alphaCoefficient = mean(alphaCoefficient)
		
	* plot slope of outcome against baseline temperature
	tw (scatter alphaCoefficient baselinePeriodTemp if tag == 1, color(navy%30)) (lfit alphaCoefficient baselinePeriodTemp if tag == 1,lwidth(thick)), legend(off) ytitle("County specific trend") xtitle("Baseline temperature") xlabel(, nogrid)ylabel(, nogrid)
	graph export "${simulations}sim3/sim3_`outcome'Trend_F.pdf", replace
			
	drop alphaCoefficient

preserve
	
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

	**** step 4:  loop over the different regression versions and simulate
	
	* run regression 1000 times 
	forvalues l = 1/1000 {
		
		* random variable based on results obtained above 
		gen random_Y = fipsFE + constant_1 + (constant_2 + betaCoefficient * baselinePeriodTemp) * year + rnormal(0,`sdEpsilon_1') // BETA METHOD
//		gen random_Y = fipsFE + constant_1 + alphaCoefficient * year + rnormal(0,`sdEpsilon_1') // ALPHA METHOD

		* run regression
		reghdfe random_Y real_under_10 real_10_20 real_20_30 real_30_40 real_40_50 real_60_70 real_70_80 real_80_90 real_over_90, absorb(fips year)
	
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
			local meanCoef`var' = `r(r500)'
							
		* drop variables
		drop meanCoef 

	}
					
	* graph evolution of coefficients
	gen variable = _n
		replace variable = . if variable > 10
		
	gen coefficient = .
		replace coefficient = `meanCoefreal_under_10' 			if variable == 1
		replace coefficient = `meanCoefreal_10_20' 			if variable == 2
		replace coefficient = `meanCoefreal_20_30' 			if variable == 3
		replace coefficient = `meanCoefreal_30_40' 			if variable == 4
		replace coefficient = `meanCoefreal_40_50' 			if variable == 5
		replace coefficient = 0 						if variable == 6
		replace coefficient = `meanCoefreal_60_70' 			if variable == 7 
		replace coefficient = `meanCoefreal_70_80' 			if variable == 8
		replace coefficient = `meanCoefreal_80_90' 			if variable == 9
		replace coefficient = `meanCoefreal_over_90' 			if variable == 10

	gen p25 = .
		replace p25 = `p25real_under_10' 		if variable == 1
		replace p25 = `p25real_10_20'			if variable == 2
		replace p25 = `p25real_20_30'			if variable == 3
		replace p25 = `p25real_30_40'			if variable == 4
		replace p25 = `p25real_40_50'			if variable == 5
		replace p25 = `p25real_60_70' 		if variable == 7
		replace p25 = `p25real_70_80' 		if variable == 8
		replace p25 = `p25real_80_90' 		if variable == 9
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
	graph tw (scatter coefficient variable, color("31 88 137")) (rcap p25 p975 variable, color("31 88 137")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small) nogrid) xtitle("") legend(off) yline(0, lpattern(dash) lcolor(red)) ylabel(, nogrid)
	graph export "${simulations}sim3/sim3_era5_`outcome'_naive.pdf", replace

	drop variable coefficient p25 p975 
	
restore

}

log close