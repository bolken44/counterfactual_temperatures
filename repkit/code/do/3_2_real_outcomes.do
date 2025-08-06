/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: All real Y, real T regressions.
*******************************************************************************
Run setup file
*********************************/
args data repkit
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"

log using "${log}3_2_real_outcomes/3_2_real_outcomes.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
* Add outcome variables
*********************************/
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

/*********************************
* Sample for mortality
*********************************/
* For mortality, use only the sample used by Deschenes and Greenstone
preserve
      use "${outcomes}weather_CC_DATA.dta", clear

      keep fips statefips year
      duplicates drop

      tempfile selectedFips
      save `selectedFips', replace
restore

* Sample period start year
local minyear_ghcn = 1968
local minyear_era5_F = 1970

/*********************************
Run
*********************************/
foreach source in era5 prism_1950 prism_1970 ghcn {

      use "${temperature}`source'_UScounty_cftemp_F_`method'.dta", clear

      xtset fips year

      * First merge in all of the cftemps we use (must rename every time)
      rename exp_* exp_`method'_*
      foreach method in {
            merge 1:1 fips year using "${temperature}`source'_cftemp_F_`method'.dta", nogen
            rename exp_* exp_`method'_*
      }

      * Add state information to drop unused states
      merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
      encode state, gen(stateCode)

      drop if state == "AK" | state == "PR" | state == "HI"
      drop _merge

      tempfile yearlydata
      save `yearlydata', replace

      ******************** Mortality (Deschenes and Greenstone, 2011) ********************

            * Merge outcome data
            merge 1:1 year fips using `mortalityByFips'
            keep if _merge == 3
            drop _merge

            * Keep fips used in the paper, add precipitation
            merge m:1 fips using `selectedFips' //if only merging fips - eg when extending sample period
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

                  ************* cftemp
                  cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) compare(none)
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_`source'`method'_`years'_before.jpg", replace

                  cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) 
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_`source'`method'_`years'.jpg", replace

                  ************* no weight
                  cftemp_plot mortality_`outcome', $bins fe(fips year) cluster(fips) 
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_noweight_`source'`method'_`years'.jpg", replace

                  ************* with trends instead of cftemp
                  cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) compare(trends, fips#c.year)
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_trends_`source'_`years'.jpg", replace

                  ************* with county-5year FE instead of cftemp
                  cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) compare(5year, county5year year)
                  graph export "${output}deschenes/`source'/harmonized/mortality_`outcome'_5year_`source'_`years'.jpg", replace

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

            ************* cftemp
            cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county) compare(none)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_`source'`method'_`years'_before.jpg", replace

            cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_`source'`method'_`years'.jpg", replace            

            ************* no weights
            cftemp_plot mortality_, $bins fe(age_county year) cluster(age_county)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_noweight_`source'`method'_`years'.jpg", replace            

            ************* with trends instead of cftemp
            cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county) compare(trends, fips#c.year)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_trends_`source'_`years'.jpg", replace

            ************* with county-5year FE instead of cftemp
            cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county) compare(5year, agecounty5year year)
            graph export "${output}deschenes/`source'/harmonized/mortality_pooled_5year_`source'_`years'.jpg", replace */

      
      ******************************* Crime (Ranson, 2014) ******************************

            use "${temperature}`source'_UScounty_monthly_cftemp_F_`method'.dta", clear

            * Merge outcome data
            merge 1:1 month year fips using `crimeByFips'
            keep if _merge == 3
            drop _merge

            * Merge states
            merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
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
            foreach outcome in violent nonviolent {
                  foreach reg in ols { 
                        * Compare no correction to cftemp
                        cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare(cftemp) method(`reg')
                        graph export "${output}other/`source'/crime_harmonized_`outcome'_cftemp_`reg'_`source'`method'.jpg", replace

                        * Just no correction
                        cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare(none) method(`reg')
                        graph export "${output}other/`source'/crime_harmonized_`outcome'_cftemp_`reg'_`source'`method'.jpg", replace

                        * Compare no correction to county-specific trends
                        cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare(trends, county_month#c.year) method(`reg')
                        graph export "${output}other/`source'/crime_harmonized_`outcome'_trends_`reg'_`source'.jpg", replace

                        * Compare no correction to county-5 year FEs
                        cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare(5year, countymonth5year year_month) method(`reg')
                        graph export "${output}other/`source'/crime_harmonized_`outcome'_5year_`reg'_`source'.jpg", replace
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

                  * county-5 year FEs
                  gen year_bin5 = floor(year/5)*5
                  egen county5year = group(fips year_bin5)

                  * Regress by crop
                  foreach outcome in corn wheat soy {
                        * Compare no correction to cftemp
                        cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare(cftemp)
                        graph export "${output}other/`source'/crops_`outcome'_cftemp_`source'`method'.jpg", replace

                        * Just no correction
                        cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare(none)
                        graph export "${output}other/`source'/crops_`outcome'_cftemp_`source'`method'_before.jpg", replace

                        * Compare no correction to county-specific trends
                        cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare(trends, fips#c.year)
                        graph export "${output}other/`source'/crops_`outcome'_trends_`source'.jpg", replace

                        * Compare no correction to county-5 year FEs
                        cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare(5year, county5year year)
                        graph export "${output}other/`source'/crops_`outcome'_5year_`source'.jpg", replace
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
                  foreach outcome in logTotalPop {
                        foreach reg in ols {
                              * Compare no correction to cftemp
                              cftemp_plot `outcome', $bins fe(fips decade) cluster(fips) compare(cftemp) method(`reg')
                              graph export "${output}other/`source'/`outcome'_cftemp_`reg'_`source'`method'.jpg", replace

                              * Just no correction
                              cftemp_plot `outcome', $bins fe(fips decade) cluster(fips) compare(none) method(`reg')
                              graph export "${output}other/`source'/`outcome'_cftemp_`reg'_`source'`method'_before.jpg", replace

                              * Compare no correction to county-specific trends
                              cftemp_plot `outcome', $bins fe(fips decade) cluster(fips) compare(trends, fips#c.decade) method(`reg')
                              graph export "${output}other/`source'/`outcome'_trends_`reg'_`source'.jpg", replace
                        }
                  }

            restore
}
