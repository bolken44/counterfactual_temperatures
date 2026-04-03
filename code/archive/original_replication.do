/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: All real Y, real T regressions.
*******************************************************************************/

clear all
set more off

ssc install ppmlhdfe
ssc install ereplace

global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

log using "${path}Haru/log/other_era5.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

********************************************************************************
** ADD OUTCOME VARIABLES 
********************************************************************************

*** population (decade level regressions)
preserve
	use "${outcomes}censusPopulationData.dta", clear 
	
	keep fips decade totalPop
	gen logTotalPop = log(totalPop)
	
	* change fips that have changed their code name
	replace fips = 46102 if fips == 46113
	
	tempfile populationByFips
	save `populationByFips', replace
restore

*** migration (year level regressions)
/* preserve
	* Outflow data
      use "${outcomes}migrationout_panel_1990_2017.dta", clear 
      foreach var in returns exemptions agg_income {
            rename `var'_totmig `var'_out
            rename `var'_nonmig `var'_non_out
            rename `var'_rate `var'_rate_out
      }

      * Inflow data
      append using "${outcomes}migrationin_panel_1990_2017.dta"

      foreach var in returns exemptions agg_income {
            rename `var'_totmig `var'_in
            rename `var'_nonmig `var'_non_in
            rename `var'_rate `var'_rate_in
      }

      * Drop if don't have both inflow and outflow
      bysort year fips: gen count = _N
      sum count, detail
      drop if count != 2

      * Collapse and create net flow
      collapse (sum) returns_* exemptions_* agg_income_*, by(year fips)
      
      foreach var in returns exemptions agg_income {
            gen `var'_net = `var'_in - `var'_out
            gen `var'_non_net = `var'_non_in - `var'_non_out
            sum `var'_non_net
      }

      * If net numbers for nonmigrants are not 0, fix obvious ones and drop the rest (8 obs)
      foreach var in returns exemptions agg_income {
            replace `var'_non_in = `var'_non_in * 2 if `var'_non_net != 0 // why??
            drop `var'_non_net
            gen `var'_non_net = `var'_non_in - `var'_non_out
            sum `var'_non_net, detail
            count if `var'_non_net != 0
            drop if `var'_non_net != 0
            
            drop `var'_non_net `var'_non_out
            rename `var'_non_in `var'_non
            gen `var'_rate_net = `var'_net / (`var'_non + `var'_net)
      }

      * Fix the rate to be the ratio of mig to non, not mig to sum of mig and non
      foreach var in returns exemptions agg_income {
            replace `var'_rate_in = `var'_in / `var'_non
            replace `var'_rate_out = `var'_out / `var'_non
            replace `var'_rate_net = `var'_net / `var'_non
      }
	
	tempfile migrationByFips
	save `migrationByFips', replace
restore */

*** crime (month level regressions)
preserve
	use "${outcomes}Ranson_2012.dta", clear

	keep if year >= 1970
	keep month pop rate_allcrimes rate_murder rate_rape rate_robbery rate_assaultaggr rate_larceny state county year 
	rename county fips
	destring fips, replace
	replace fips = 46102 if fips == 46113

	tempfile crimeByFips
	save `crimeByFips', replace
	
restore

*** crops
foreach crop in corn wheat soy {
      preserve 
            use "${outcomes}`crop'.dta", clear

            destring fips, replace
            rename value `crop'Output
            gen log`crop'Output = log(`crop'Output)
            
            * keep relevant time period
            keep if inrange(year,1970,2019)
            
            tempfile `crop'ByFips
            save ``crop'ByFips'
      restore
}

**** mortality (full panel)
preserve 
	use "${outcomes}mortality_countyPanel_19682016.dta", clear

	* construct mortality rates
	foreach var in allAges less1 1_44 45_64 more65{
		gen mortality_`var' = (deaths_`var'/population_`var')*100000
	}
	* keep relevant time period
	keep if inrange(year,1968,2019)
	
	tempfile mortalityByFips
	save `mortalityByFips'
restore

* select sample used by Deschenes and Greenstone, add precipitation
preserve
      use "${outcomes}WEATHER_CC_DATA.dta", clear

      keep fips statefips year smean* mprcp* // //year ssyy
      duplicates drop

      tempfile selectedFips
      save `selectedFips', replace
restore

**** mortality from Barreca et al (2016)
/* preserve
	use "${outcomes}DATA_1900_2004.dta", clear

      keep if year>=1960

      gen yearmo=year*1000 + month
      gen statemo=stfips*1000 + month

      quiet tab month, gen(monthfe)
      drop monthfe1

      forvalues i=2/12 {
            gen sh_0000_monthfe`i'=sh_0000*monthfe`i'
            gen sh_4564_monthfe`i'=sh_4564*monthfe`i'
            gen sh_6599_monthfe`i'=sh_6599*monthfe`i'
            gen lri_monthfe`i'=lri*monthfe`i'
      }

      gen year2=year*year
      gen ymdate=ym(year, month)
      sort stfips ymdate
      xtset stfips ymdate

      forvalues i=1/10 {
            gen L1_b10_`i'=L1.b10_`i'
            gen D1_b10_`i'=D1.b10_`i'
      }
	
	tempfile Barreca2016
	save `Barreca2016'
restore */

********************************************************************************
** Regressors
********************************************************************************
adopath + "${path}/Haru/cftemp"
run "${path}/Haru/cftemp/cftemp_plot.ado"

********************************************************************************
** ADD WEATHER DATA
********************************************************************************
local data_era5 = "${weather}era5_UScounty_1970_2019_cftemp.dta"
local data_month_era5 = "${weather}monthly/era5_monthly_UScounty_1970_2019_cftemp.dta"
local bins_era5 = "binsize(5) lb(-10) ub(35) omit(6)"

local data_era5_F = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F = "${weather}monthly/era5_monthly_UScounty_1970_2019_cftemp_F.dta"
local bins_era5_F = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_year_bayes = "${weather}era5_UScounty_1970_2019_cftemp_F_bayes.dta"
local data_month_era5_F_year_bayes = "${weather}monthly/era5_monthly_UScounty_1970_2019_cftemp_F_bayes.dta"

local data_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp.dta"
local prcp_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp_prcp.dta"
local data_month_ghcn = "${weather}monthly/ghcn_monthly_UScounty_1968_2002_cftemp.dta"
local prcp_month_ghcn = "${weather}monthly/ghcn_monthly_UScounty_1968_2002_cftemp_prcp.dta"
local bins_ghcn = "binsize(10) lb(10) ub(90) omit(6)"

local data_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp.dta"
local prcp_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp_prcp.dta"
local data_month_ghcn_ext = "${weather}monthly/ghcn_monthly_UScounty_1968_2016_cftemp.dta"
local prcp_month_ghcn_ext = "${weather}monthly/ghcn_monthly_UScounty_1968_2016_cftemp_prcp.dta"
local bins_ghcn_ext = "binsize(10) lb(10) ub(90) omit(6)"

local data_schlenker = "${weather}schlenker_UScounty_1950_2019_cftemp.dta"
local data_month_schlenker = "${weather}monthly/schlenker_UScounty_1950_2019_cftemp.dta"
local bins_schlenker = "binsize(5) lb(-10) ub(35) omit(6)"

local data_schlenker_F = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
local data_month_schlenker_F = "${weather}monthly/schlenker_UScounty_1950_2019_cftemp_F.dta"
local bins_schlenker_F = "binsize(10) lb(10) ub(90) omit(6)"

* Sample period for mortality results
local minyear_ghcn = 1968
local minyear_era5_F = 1970

** Average temperatures
* GHCN (Deschenes and Greenstone daily data)
/* preserve
      use "${path}Haru/data/ghcn_countylevel_1968_2002.dta", clear
      bysort fips year: egen mean_temp = mean(tmean)
      bysort fips year: gen unique = _n == 1

      sum mean_temp if year == 1968 & unique == 1, detail
      gen hightemp = (mean_temp > `r(p50)')
      replace hightemp = 0 if year != 1968
      bysort fips: ereplace hightemp = max(hightemp)

      keep hightemp mean_temp fips year
      duplicates drop
      tempfile ghcn_avgtemp
      save `ghcn_avgtemp'
restore */

* ERA 5
preserve
      /* use "${path}DTA_US/countyLevel_US_1970_2019.dta", clear */
      use "${path}DTA_US/countyLevel_USPanel_1970_2019.dta", clear

      /* keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
      reshape long avg_temp_daytime avg_temp_day, i(fips year  latitude longitude month) j(day)
      drop latitude longitude
      drop if avg_temp_daytime == .

      bysort fips year: egen mean_temp = mean(avg_temp_daytime)
      bysort fips year: gen unique = _n == 1

      sum mean_temp if year == 1970  & unique == 1, detail
      gen hightemp = (mean_temp > `r(p50)') 
      replace hightemp = 0 if year != 1970
      bysort fips: ereplace hightemp = max(hightemp)  */

      keep fips year avg_yearly_temp
      gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
      bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

      sum baselinePeriodTemp, detail
      local medianPreTemp = `r(p50)'
      gen hightemp = baselinePeriodTemp > `medianPreTemp'

      keep hightemp fips year
      duplicates drop
      tempfile era5_avgtemp
      save `era5_avgtemp'
      tempfile era5_F_avgtemp
      save `era5_F_avgtemp'
restore 

* Schlenker- PRISM
/* preserve
      use "${path}Haru/data/PRISM_Schlenker/appended.dta", clear
      bysort fips year: egen mean_temp = mean(tMax)
      bysort fips year: gen unique = _n == 1

      sum mean_temp if year == 1970 & unique == 1, detail
      gen hightemp = (mean_temp > `r(p50)')
      replace hightemp = 0 if year != 1968
      bysort fips: ereplace hightemp = max(hightemp)

      keep hightemp mean_temp fips year
      duplicates drop
      tempfile schlenker_avgtemp
      save `schlenker_avgtemp'
      tempfile schlenker_F_avgtemp
      save `schlenker_F_avgtemp'
restore */

** GHCN weather variables
/* preserve
      use "${path}Haru/processed/ghcn_UScountylevel_1968_2016.dta", clear
      gen tmean = (TMAX + TMIN) / 2
      bysort fips year: egen mean_temp = mean(tmean)
      bysort fips year: gen unique = _n == 1

      * Average temperature
      sum mean_temp if year == 1968 & unique == 1, detail
      gen hightemp = (mean_temp > `r(p50)')
      replace hightemp = 0 if year != 1968
      bysort fips: ereplace hightemp = max(hightemp)

      * Rain Bins
      bysort year fips: egen annual_prcp = total(PRCP)
	replace annual_prcp = annual_prcp / 100

      gen mprcp0 = (annual_prcp < 10)
      local j = 10
      forval i = 1/10 {
            gen mprcp`i' = (annual_prcp >= `j' & annual_prcp < `j' + 5)
            local j = `j' + 5
      }
      gen mprcp11 = (annual_prcp >= 60)

      * Extreme rain indicators (used in Barreca et al, Mullins & Bharadwaj)
      bysort fips: egen prcp75 = pctile(annual_prcp), p(75)
      gen exprcp75 = (annual_prcp > prcp75)
      bysort fips: egen prcp25 = pctile(annual_prcp), p(25)
      gen exprcp25 = (annual_prcp < prcp25)

      keep hightemp mean_temp fips year mprcp* exprcp*
      duplicates drop
      tempfile ghcn_rain
      save `ghcn_rain'

      tempfile ghcn_ext_avgtemp
      save `ghcn_ext_avgtemp'
restore */
********************************************************************************
** RUN
********************************************************************************
local method "_year_bayes"
foreach source in era5_F { //ghcn schlenker era5_F

      use "`data_`source'`method''", clear

      xtset fips year

      * Merge precipitation calculated from GHCN data
      /* merge 1:1 fips year using `ghcn_rain'
      drop _merge hightemp mean_temp */

      * Add state information to drop unused states
      preserve
            import delimited "${path}Haru/data/county_centroid.csv", clear
            keep fips state

            tempfile fipsToState
            save `fipsToState', replace
      restore

      merge m:1 fips using `fipsToState'
      encode state, gen(stateCode)

      drop if state == "AK" | state == "PR" | state == "HI"
      drop _merge

      tempfile yearlydata
      save `yearlydata', replace

      ******************** Mortality (Deschenes and Greenstone, 2011) ********************

            /* * Merge outcome data
            merge 1:1 year fips using `mortalityByFips'
            keep if _merge == 3
            drop _merge

            * Keep fips used in the paper, add precipitation
            /* merge m:1 fips using `selectedFips' //if only merging fips - eg when extending sample period */
            merge m:1 year fips using `selectedFips' //if merging smean, mprcp
            keep if _merge == 3
            drop _merge

            * Merge average temps
            merge m:1 year fips using ``source'_avgtemp'
            keep if _merge == 3
            drop _merge

            * Declare years to use (paper: GHCN 1968-2002)
            sum year
            keep if inrange(year,`minyear_`source'',2002)
            local years "`minyear_`source''-2002"

            * State by year FE
            egen year_state = group(year state)

            * county - 5 year FEs
            gen year_bin5 = floor(year/5)*5
            egen county5year = group(fips year_bin5)

            tempfile deschenes_data
            save `deschenes_data'

            * Regress by age group
            foreach outcome in allAges more65 { //less1 1_44 45_64 

                  use `deschenes_data', clear
                  ************* Paper
                        /* preserve
                        * Variable to mark bins
                        gen variable1 = _n
                        replace variable1 = . if _n > 10

                        * Generate variables to hold estimates
                        gen coef1 = .
                        gen lb1 = .
                        gen ub1 = .
                        local x = 1
                        gen varName = ""

                        reghdfe mortality_`outcome' smean1-smean5 smean7-smean10 mprcp1-mprcp11 [aw=population_`outcome'], absorb(fips year_state) cluster(fips)

                        * Save estimates
                        local r2_`version': di %4.3f `e(r2)'
                        ds smean1-smean5 smean7-smean10
                        foreach var in `r(varlist)' {
                        
                              * save lincom values in generated variable
                              qui lincom `var'
                              replace varName = "`var'" 		if _n == `x'
                              replace coef1 = `r(estimate)'     if _n == `x'
                              replace lb1 = `r(lb)' 		if _n == `x'
                              replace ub1 = `r(ub)' 		if _n == `x'
                              
                              * replace iteration variable
                              local x = `x' + 1
                        }

                        replace variable1 = variable1 + 1 if variable1 >= 6
                        replace variable1 = 6 if variable1 == 10 + 1
                        replace lb1 = 0 if variable1 == 6
                        replace ub1 = 0 if variable1 == 6
                        replace coef1 = 0 if variable1 == 6
                        sort variable1

                        replace variable1 = variable1 - 0.1

                        gen coef1_lab = string(round(coef1, 0.01), "%03.2f")

                        twoway (scatter coef1 variable1, mlabel(coef1_lab) mlabpos(12) msymbol(O) connect(l) lcolor(blue) mcolor(red) lwidth(medium)) ///
                              (scatter ub1 variable1, msymbol(O) connect(l) lpattern(dash) lcolor(gray) mcolor(gray)) ///
                              (scatter lb1 variable1, msymbol(O) connect(l) lpattern(dash) lcolor(gray) mcolor(gray)), ///
                              xlab(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small) grid  glcolor(gs12) glwidth(thin) valuelabel) ///
                              yline(0, lcolor(black)) legend(order(1 "Estimate" 2 "95% C.I.")) ///
                              graphregion(color(white))
                        graph export "${output}deschenes/`source'/paper/mortality_`outcome'_`source'_`years'.jpg", replace
                        restore */

                  ************* cftemp
                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) compare(none)
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_`source'`method'_`years'_before.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) 
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_`source'`method'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) control(mprcp1-mprcp11)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_`outcome'_`source'`method'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year_state) cluster(fips)
                  graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_`outcome'_`source'`method'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year_state) cluster(fips) control(mprcp1-mprcp11)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_`outcome'_`source'`method'_`years'.jpg", replace

                  ************* no weight
                  cftemp_plot mortality_`outcome', `bins_`source'' fe(fips year) cluster(fips) 
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_noweight_`source'`method'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' fe(fips year) cluster(fips) control(mprcp1-mprcp11)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_`outcome'_noweight_`source'`method'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' fe(fips year_state) cluster(fips)
                  graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_`outcome'_noweight_`source'`method'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' fe(fips year_state) cluster(fips) control(mprcp1-mprcp11)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_`outcome'_noweight_`source'`method'_`years'.jpg", replace

                  ************* with trends instead of cftemp
                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) compare(trends, fips#c.year)
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_trends_`source'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) control(mprcp1-mprcp11) compare(trends, fips#c.year)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_`outcome'_trends_`source'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year_state) cluster(fips) compare(trends, fips#c.year)
                  graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_`outcome'_trends_`source'_`years'.jpg", replace

                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year_state) cluster(fips) control(mprcp1-mprcp11) compare(trends, fips#c.year)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_`outcome'_trends_`source'_`years'.jpg", replace

                  ************* with county-5year FE instead of cftemp
                  cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) compare(5year, county5year year)
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_5year_`source'_`years'.jpg", replace
                  
                  
                  ************* cftemp, adaptation
                  /* local labnaive = "naive"
                  local labcftemp = "cftemp"

                  foreach ver in naive cftemp {

                        cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) compare(`ver' het, hightemp)
                        graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_`source'`method'_`years'_`lab`ver''.jpg", replace

                        cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year) cluster(fips) control(mprcp1-mprcp11) compare(`ver' het, hightemp)
                        graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_`outcome'_`source'`method'_`years'_`lab`ver''.jpg", replace

                        cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year_state) cluster(fips) compare(`ver' het, hightemp)
                        graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_`outcome'_`source'`method'_`years'_`lab`ver''.jpg", replace

                        cftemp_plot mortality_`outcome', `bins_`source'' aweights(population_`outcome') fe(fips year_state) cluster(fips) control(mprcp1-mprcp11) compare(`ver' het, hightemp)
                        graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_`outcome'_`source'`method'_`years'_`lab`ver''.jpg", replace

                  } */


            }

            ************** Regress all age groups pooled ************* 
            use `deschenes_data', clear
            reshape long deaths_ mortality_ population_, i(fips year) j(age) string
            egen ageGroup = group(age)
            egen age_county = group(ageGroup fips)
            drop if age == "allAges"

            * agegroup - county - 5 year FEs
            egen agecounty5year = group(age_county year_bin5)

            tempfile reshaped_data
            save `reshaped_data'
      
            ************* Paper
                  * Variable to mark bins
                  /* preserve
                  gen variable1 = _n
                  replace variable1 = . if _n > 10

                  * Generate variables to hold estimates
                  gen coef1 = .
                  gen lb1 = .
                  gen ub1 = .
                  local x = 1
                  gen varName = ""

                  reghdfe mortality_ smean1-smean5 smean7-smean10 mprcp1-mprcp11 [aw=population_], absorb(age_county year_state) cluster(fips)

                  * Save estimates
                  local r2_`version': di %4.3f `e(r2)'
                  ds smean1-smean5 smean7-smean10
                  foreach var in `r(varlist)' {
                  
                        * save lincom values in generated variable
                        qui lincom `var'
                        replace varName = "`var'" 		if _n == `x'
                        replace coef1 = `r(estimate)'     if _n == `x'
                        replace lb1 = `r(lb)' 		if _n == `x'
                        replace ub1 = `r(ub)' 		if _n == `x'
                        
                        * replace iteration variable
                        local x = `x' + 1
                  }

                  replace variable1 = variable1 + 1 if variable1 >= 6
                  replace variable1 = 6 if variable1 == 10 + 1
                  replace lb1 = 0 if variable1 == 6
                  replace ub1 = 0 if variable1 == 6
                  replace coef1 = 0 if variable1 == 6
                  sort variable1

                  replace variable1 = variable1 - 0.1

                  gen coef1_lab = string(round(coef1, 0.01), "%03.2f")

                  twoway (scatter coef1 variable1, mlabel(coef1_lab) mlabpos(12) msymbol(O) connect(l) lcolor(blue) mcolor(red) lwidth(medium)) ///
                        (scatter ub1 variable1, msymbol(O) connect(l) lpattern(dash) lcolor(gray) mcolor(gray)) ///
                        (scatter lb1 variable1, msymbol(O) connect(l) lpattern(dash) lcolor(gray) mcolor(gray)), ///
                        xlab(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small) grid  glcolor(gs12) glwidth(thin) valuelabel) ///
                        yline(0, lcolor(black)) legend(order(1 "Estimate" 2 "95% C.I.")) ///
                        graphregion(color(white))
                  graph export "${output}deschenes/`source'/paper/mortality_pooled_`source'_`years'.jpg", replace
                  restore */

            ************* cftemp
            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county) compare(none)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_`source'`method'_`years'_before.jpg", replace

            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_`source'`method'_`years'.jpg", replace            

            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county) control(mprcp1-mprcp11)
            graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_pooled_`source'`method'_`years'.jpg", replace

            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year_state) cluster(age_county)
            graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_pooled_`source'`method'_`years'.jpg", replace

            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year_state) cluster(age_county) control(mprcp1-mprcp11)
            graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_pooled_`source'`method'_`years'.jpg", replace

            ************* no weights
            cftemp_plot mortality_, `bins_`source'' fe(age_county year) cluster(age_county)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_noweight_`source'`method'_`years'.jpg", replace            

            cftemp_plot mortality_, `bins_`source'' fe(age_county year) cluster(age_county) control(mprcp1-mprcp11)
            graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_pooled_noweight_`source'`method'_`years'.jpg", replace

            cftemp_plot mortality_, `bins_`source'' fe(age_county year_state) cluster(age_county)
            graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_pooled_noweight_`source'`method'_`years'.jpg", replace

            cftemp_plot mortality_, `bins_`source'' fe(age_county year_state) cluster(age_county) control(mprcp1-mprcp11)
            graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_pooled_noweight_`source'`method'_`years'.jpg", replace

            ************* with trends instead of cftemp
            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county) compare(trends, fips#c.year)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_trends_`source'_`years'.jpg", replace

            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county) control(mprcp1-mprcp11) compare(trends, fips#c.year)
            graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_pooled_trends_`source'_`years'.jpg", replace

            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year_state) cluster(age_county) compare(trends, fips#c.year)
            graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_pooled_trends_`source'_`years'.jpg", replace

            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year_state) cluster(age_county) control(mprcp1-mprcp11) compare(trends, fips#c.year)
            graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_pooled_trends_`source'_`years'.jpg", replace

            ************* with county-5year FE instead of cftemp
            cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county) compare(5year, agecounty5year year)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_5year_`source'_`years'.jpg", replace */
      
            ************* cftemp, adaptation
            /* local labnaive = "naive"
            local labcftemp = "cftemp"

            foreach ver in naive cftemp {

                  cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county) compare(`ver' het, hightemp)
                  graph export "${output}deschenes/`source'/harmonized/mortality_pooled_`source'`method'_`years'_`lab`ver''.jpg", replace

                  cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year) cluster(age_county) control(mprcp1-mprcp11) compare(`ver' het, hightemp)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_nosyFE/mortality_pooled_`source'`method'_`years'_`lab`ver''.jpg", replace

                  cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year_state) cluster(age_county) compare(`ver' het, hightemp)
                  graph export "${output}deschenes/`source'/replication_mytemp_noprcp_syFE/mortality_pooled_`source'`method'_`years'_`lab`ver''.jpg", replace

                  cftemp_plot mortality_, `bins_`source'' aweights(population_) fe(age_county year_state) cluster(age_county) control(mprcp1-mprcp11) compare(`ver' het, hightemp)
                  graph export "${output}deschenes/`source'/replication_mytemp_theirprcp_syFE/mortality_pooled_`source'`method'_`years'_`lab`ver''.jpg", replace
            } */
      
     
      ************************ Mortality (Barreca et al, 2016) **************************
            /* use "`data_month_`source''", clear

            * Merge states
            merge m:1 fips using `fipsToState'
            encode state, gen(stateCode)
            drop _merge 

            * Merge statefips
            merge m:1 fips using `selectedFips'
            drop _merge

            * Collapse to state level
            merge m:1 year fips using `mortalityByFips'
            drop _merge
            bysort year statefips: egen statepop = total(population_allAges)
            
            ds real* exp*
            foreach var in `r(varlist)' {
                  bysort year statefips: egen state_`var' = total(`var' * population_allAges)
            }

            collapse (mean) statepop state_*, by(year statefips month)

            ds state_*
            foreach var in `r(varlist)' {
                  local binname = substr("`var'", 7, .)
                  gen `binname' = `var' / statepop
            }

            * Merge outcome data
            rename statefips stfips
            merge 1:1 month year stfips using `Barreca2016'
            keep if _merge == 3
            drop _merge

            foreach outcome in lndrate {
                  * Harmonized spec
                  cftemp_plot `outcome', `bins_`source'' omit(7) fe(yearmo statemo) cluster(stfips) compare(cftemp) control(sh_0000 sh_4564 sh_6599 lri sh_0000_monthfe* sh_4564_monthfe* sh_6599_monthfe* lri_monthfe*) aweights(totalpop)
                  graph export "${output}barreca/`source'/harmonized_`outcome'_cftemp_`source'`method'.jpg", replace

                  * No precipitation
                  cftemp_plot `outcome', `bins_`source'' omit(7) fe(yearmo i.statemo#c.year2 i.statemo#c.year) cluster(stfips) compare(cftemp) control(sh_0000 sh_4564 sh_6599 lri sh_0000_monthfe* sh_4564_monthfe* sh_6599_monthfe* lri_monthfe*) aweights(totalpop)
                  graph export "${output}barreca/`source'/noprcp_`outcome'_cftemp_`source'`method'.jpg", replace

                  * No interactions between state-month FE and years
                  cftemp_plot `outcome', `bins_`source'' omit(7) fe(yearmo statemo) cluster(stfips) compare(cftemp) control(devp25 devp75 sh_0000 sh_4564 sh_6599 lri sh_0000_monthfe* sh_4564_monthfe* sh_6599_monthfe* lri_monthfe*) aweights(totalpop)
                  graph export "${output}barreca/`source'/nosyFE_`outcome'_cftemp_`source'`method'.jpg", replace

                  * Paper spec
                  cftemp_plot `outcome', `bins_`source'' omit(7) fe(yearmo i.statemo#c.year2 i.statemo#c.year) cluster(stfips) compare(cftemp) control(devp25 devp75 sh_0000 sh_4564 sh_6599 lri sh_0000_monthfe* sh_4564_monthfe* sh_6599_monthfe* lri_monthfe*) aweights(totalpop)
                  graph export "${output}barreca/`source'/paper_`outcome'_cftemp_`source'`method'.jpg", replace

                  /* cftemp_plot rate_`outcome', `bins_`source'' fe(fips year month) cluster(fips) compare(trends, county_month#c.year)
                  graph export "${output}barreca/`source'/barreca_`outcome'_trends_`source'`method'.jpg", replace */
            }
      */
      ******************************* Crime (Ranson, 2014) ******************************

            use "`data_month_`source'`method''", clear

            * Merge precipitation
            /* merge 1:1 fips month year using "`prcp_month_`source''"
            drop _merge */

            * Merge outcome data
            merge 1:1 month year fips using `crimeByFips'
            keep if _merge == 3
            drop _merge

            * Merge states
            merge m:1 fips using `fipsToState'
            keep if _merge == 3

            sum year

            * Outcome data categories
            gen rate_violent = rate_murder + rate_rape + rate_assaultaggr
            gen rate_nonviolent = rate_robbery + rate_larceny

            egen county_month = group(fips month)
            egen year_month = group(year month)

            * county - 5 year FEs
            gen year_bin5 = floor(year/5)*5
            egen county5year = group(fips year_bin5)
            egen countymonth5year = group(county_month year_bin5)

            * state-by-month FE
            egen state_month = group(state month)
            egen county1year = group(fips year)

            * Regress by crime category
            foreach outcome in violent nonviolent { //murder rape robbery assaultaggr larceny
                  foreach reg in ols {  //ppml
                        /* * First attempt at harmonized
                        cftemp_plot rate_`outcome', `bins_`source'' fe(fips year month) cluster(fips) compare(none) method(`reg')
                        graph export "${output}other/`source'/crime_`outcome'_cftemp_`reg'_`source'`method'_before.jpg", replace

                        cftemp_plot rate_`outcome', `bins_`source'' fe(fips year month) cluster(fips) compare(cftemp) method(`reg')
                        graph export "${output}other/`source'/crime_`outcome'_cftemp_`reg'_`source'`method'.jpg", replace

                        cftemp_plot rate_`outcome', `bins_`source'' fe(fips year month) cluster(fips) compare(trends, county_month#c.year)
                        graph export "${output}other/`source'/crime_`outcome'_trends_`source'`method'.jpg", replace

                        cftemp_plot rate_`outcome', `bins_`source'' fe(fips year month) cluster(fips) compare(5year, county5year year month)
                        graph export "${output}other/`source'/crime_`outcome'_5year_`source'`method'.jpg", replace

                        * Different sets of TWFE (county and month / year and month)
                        cftemp_plot rate_`outcome', `bins_`source'' fe(fips month) cluster(fips) compare(cftemp) 
                        graph export "${output}other/`source'/crime_`outcome'_fipsmonth_`source'`method'.jpg", replace

                        cftemp_plot rate_`outcome', `bins_`source'' fe(year month) cluster(fips) compare(cftemp) 
                        graph export "${output}other/`source'/crime_`outcome'_yearmonth_`source'`method'.jpg", replace

                        cftemp_plot rate_`outcome', `bins_`source'' fe(fips month) cluster(fips) compare(5year, county5year month)
                        graph export "${output}other/`source'/crime_`outcome'_5year_fipsmonth_`source'`method'.jpg", replace */

                        * OLS version of Ranson spec
                        cftemp_plot rate_`outcome', `bins_`source'' fe(state_month county1year) cluster(fips) compare(cftemp) method(`reg')
                        graph export "${output}other/`source'/crime_paper_`outcome'_cftemp_`reg'_`source'`method'.jpg", replace

                        // I don't know if these make sense
                        /* cftemp_plot rate_`outcome', `bins_`source'' fe(state_month county1year) cluster(fips) compare(trends, county_month#c.year) method(`reg')
                        graph export "${output}other/`source'/crime_paper_`outcome'_trends_`reg'_`source'`method'.jpg", replace */

                        /* cftemp_plot rate_`outcome', `bins_`source'' fe(state_month county1year) cluster(fips) compare(5year, countymonth5year year_month) method(`reg')
                        graph export "${output}other/`source'/crime_paper_`outcome'_5year_`reg'_`source'`method'.jpg", replace */
                        
                        * Correct version
                        cftemp_plot rate_`outcome', `bins_`source'' fe(county_month year_month) cluster(fips) compare(cftemp) method(`reg')
                        graph export "${output}other/`source'/crime_harmonized_`outcome'_cftemp_`reg'_`source'`method'.jpg", replace

                        /* cftemp_plot rate_`outcome', `bins_`source'' fe(county_month year_month) cluster(fips) compare(trends, county_month#c.year) method(`reg')
                        graph export "${output}other/`source'/crime_harmonized_`outcome'_trends_`reg'_`source'.jpg", replace

                        cftemp_plot rate_`outcome', `bins_`source'' fe(county_month year_month) cluster(fips) compare(5year, countymonth5year year_month) method(`reg')
                        graph export "${output}other/`source'/crime_harmonized_`outcome'_5year_`reg'_`source'.jpg", replace */

                  }
            }

      ************ Crops (Schlenker and Roberts, 2009 and additional crops) ***************
            use `yearlydata', clear
            preserve

                  * Merge outcome data
                  foreach crop in corn soy wheat {
                        merge 1:1 year fips using ``crop'ByFips', nogen
                  }

                  sum year

                  * county - 5 year FEs
                  gen year_bin5 = floor(year/5)*5
                  egen county5year = group(fips year_bin5)

                  * Regress by crop
                  foreach outcome in corn wheat soy {
                        cftemp_plot log`outcome'Output, `bins_`source'' fe(fips year) cluster(fips) compare(cftemp)
                        graph export "${output}other/`source'/crops_`outcome'_cftemp_`source'`method'.jpg", replace

                        /* cftemp_plot log`outcome'Output, `bins_`source'' fe(fips year) cluster(fips) compare(none)
                        graph export "${output}other/`source'/crops_`outcome'_cftemp_`source'`method'_before.jpg", replace

                        cftemp_plot log`outcome'Output, `bins_`source'' fe(fips year) cluster(fips) compare(trends, fips#c.year)
                        graph export "${output}other/`source'/crops_`outcome'_trends_`source'.jpg", replace

                        cftemp_plot log`outcome'Output, `bins_`source'' fe(fips year) cluster(fips) compare(5year, county5year year)
                        graph export "${output}other/`source'/crops_`outcome'_5year_`source'.jpg", replace */
                  }

            restore

      ******************************* Population ******************************
            preserve

                  * Aggregate to decade level
                  gen decade = year/10
                  replace decade = floor(decade)
                  collapse (sum) exp_* real_*, by(decade fips state stateCode)

                  * Merge outcome data
                  merge 1:1 decade fips using `populationByFips'

                  * Regress
                  foreach outcome in logTotalPop { //totalPop 
                        foreach reg in ols { //ppml 
                              cftemp_plot `outcome', `bins_`source'' fe(fips decade) cluster(fips) compare(cftemp) method(`reg')
                              graph export "${output}other/`source'/`outcome'_cftemp_`reg'_`source'`method'.jpg", replace

                              /* cftemp_plot `outcome', `bins_`source'' fe(fips decade) cluster(fips) compare(none) method(`reg')
                              graph export "${output}other/`source'/`outcome'_cftemp_`reg'_`source'`method'_before.jpg", replace

                              cftemp_plot `outcome', `bins_`source'' fe(fips decade) cluster(fips) compare(trends, fips#c.decade) method(`reg')
                              graph export "${output}other/`source'/`outcome'_trends_`reg'_`source'.jpg", replace */
                        }
                  }

            restore
      
      ******************************* Migration ******************************
            /* preserve

                  keep if inrange(year, 1990,2017)
                  merge 1:1 year fips using `migrationByFips'
                  drop if _merge != 3

                  gen real_under_30 = real_under_10 + real_10_20 + real_20_30
                  gen exp_under_30 = exp_under_10 + exp_10_20 + exp_20_30
                  drop real_under_10 real_10_20 real_20_30 exp_under_10 exp_10_20 exp_20_30

                  * Regress
                  foreach outcome in returns exemptions agg_income {
                        foreach flow in out in net {
                              cftemp_plot `outcome'_rate_`flow', binsize(10) lb(30) ub(90) omit(6) fe(fips year) cluster(fips) control(exprcp*)
                              graph export "${output}other/`source'/`outcome'_`flow'rate_cftemp_`source'`method'.jpg", replace
                        }
                  }
            
            restore */
}
