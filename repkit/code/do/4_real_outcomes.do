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
/* global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/" */

log using "${log}4_real_outcomes/4_real_outcomes.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/* local outcomes "population more65 violent nonViolent corn soy wheat" //allAges less1 1_44 45_64 more65
local outcome = word("`outcomes'", `task') */

/*********************************
* Add outcome variables
*********************************/
*** population (decade level regressions)
use "${outcomes}censusPopulationData.dta", clear 

keep fips decade totalPop
gen logTotalPop = log(totalPop)

* change fips that have changed their code name
replace fips = 46102 if fips == 46113

tempfile populationByFips
save `populationByFips', replace

*** crime (month level regressions)
use "${outcomes}Ranson_2012.dta", clear

keep if year >= 1970
keep month pop rate_allcrimes rate_murder rate_rape rate_robbery rate_assaultaggr rate_larceny state county year 
rename county fips
destring fips, replace
replace fips = 46102 if fips == 46113

* generate outcome variable
egen violent = rowtotal(rate_murder rate_rape rate_assaultaggr)
egen nonViolent = rowtotal(rate_robbery rate_larceny)

tempfile crimeByFips
save `crimeByFips', replace

*** crops
foreach outcome in soy wheat corn {
      use "${outcomes}`outcome'.dta", clear

      destring fips, replace
      rename value `outcome'Output
      gen log`outcome'Output = log(`outcome'Output)
      
      * keep relevant time period
      keep if inrange(year,1970,2019)
      
      tempfile `outcome'ByFips
      save ``outcome'ByFips', replace
}


**** mortality (full panel)
use "${outcomes}mortality_countyPanel_19682016.dta", clear

* construct mortality rates
foreach outcome in more65 allAges less1 1_44 45_64 {
      gen mortality_`outcome' = (deaths_`outcome'/population_`outcome')*100000
}

* keep relevant time period
keep if inrange(year,1968,2019)
/* replace mortality_more65 = . if year > 2002 */

tempfile mortalityByFips
save `mortalityByFips', replace

/*********************************
* Sample for mortality
*********************************/
* For mortality, use only the sample used by Deschenes and Greenstone=
use "${data}WEATHER_CC_DATA.dta", clear

keep fips // statefips year
duplicates drop

tempfile selectedFips
save `selectedFips', replace

* Sample period start year
local minyear_ghcn = 1968
local minyear_era5 = 1970

/*********************************
Run
*********************************/
foreach source in era5 { //prism_1950 prism_1970 ghcn 

      foreach method in 5year_bayes trends 5year bayes { // trends 5year year chebyshev 

            if "`method'" == "bayes" | "`method'" == "chebyshev" {
                  use "${temperature}`source'_UScounty_cftemp_F_bin${binsize}_`method'.dta", clear
                  /* use "${weather}era5_UScounty_1970_2019_cftemp_F_`method'.dta", clear */
            }
            if "`method'" == "5year_bayes" {
                  use "${temperature}`source'_UScounty_cftemp_F_bin${binsize}_bayes.dta", clear
            }
            if "`method'" == "trends" | "`method'" == "5year" | "`method'" == "year" {
                  use "${temperature}`source'_UScounty_cftemp_F_bin${binsize}_year.dta", clear
                  /* use "${weather}era5_UScounty_1970_2019_cftemp_F.dta", clear */
            }

            xtset fips year

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
                  foreach outcome in more65 { //allAges less1 1_44 45_64 

                        use `deschenes_data', clear

                        if "`method'" == "year" | "`method'" == "bayes" | "`method'" == "chebyshev" {
                              /* cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) compare1(none)
                              graph export "${figures}real_outcomes/mortality_`outcome'_`source'_`method'_`years'_before.pdf", replace */

                              cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) 
                              graph export "${figures}real_outcomes/mortality_`outcome'_`source'_`method'_`years'.pdf", replace

                              ************* no weight
                              /* cftemp_plot mortality_`outcome', $bins fe(fips year) cluster(fips) 
                              graph export "${figures}real_outcomes/mortality_`outcome'_noweight_`source'_`method'_`years'.pdf", replace */
                        }

                        if "`method'" == "trends" {
                              cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) compare1(trends, fips#c.year)
                              graph export "${figures}real_outcomes/mortality_`outcome'_`source'_trends_`years'.pdf", replace
                        }
                        
                        if "`method'" == "5year" {
                              cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) compare1(5year, county5year year)
                              graph export "${figures}real_outcomes/mortality_`outcome'_`source'_5year_`years'.pdf", replace
                        }
                        if "`method'" == "5year_bayes" {
                              cftemp_plot mortality_`outcome', $bins aweights(population_`outcome') fe(fips year) cluster(fips) compare1(cftemp) compare2(5year, county5year year)
                              graph export "${figures}real_outcomes/mortality_`outcome'_`source'_5year_bayes_`years'.pdf", replace
                        }
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

                  if "`method'" == "year" | "`method'" == "bayes" | "`method'" == "chebyshev" {
                        /* cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county) compare1(none)
                        graph export "${figures}real_outcomes/mortality_pooled_`source'_`method'_`years'_before.pdf", replace */

                        cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county)
                        graph export "${figures}real_outcomes/mortality_pooled_`source'_`method'_`years'.pdf", replace

                        ************* no weights
                        /* cftemp_plot mortality_, $bins fe(age_county year) cluster(age_county)
                        graph export "${figures}real_outcomes/mortality_pooled_noweight_`source'_`method'_`years'.pdf", replace  */
                  }           

                  if "`method'" == "trends" {
                        cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county) compare1(trends, fips#c.year)
                        graph export "${figures}real_outcomes/mortality_pooled_`source'_trends_`years'.pdf", replace
                  }

                  if "`method'" == "5year" {
                        cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county) compare1(5year, agecounty5year year)
                        graph export "${figures}real_outcomes/mortality_pooled_`source'_5year_`years'.pdf", replace
                  }

                  if "`method'" == "5year_bayes" {
                        cftemp_plot mortality_, $bins aweights(population_) fe(age_county year) cluster(age_county) compare1(cftemp) compare2(5year, agecounty5year year)
                        graph export "${figures}real_outcomes/mortality_pooled_`source'_5year_bayes_`years'.pdf", replace
                  }
            
            ******************************* Crime (Ranson, 2014) ******************************

                  use "${temperature}`source'_UScounty_monthly_cftemp_F_bin${binsize}_bayes.dta", clear
                  /* if "`method'" == "bayes" | "`method'" == "chebyshev" { // we only need to do bayes for cftemp
                        use "${temperature}`source'_UScounty_monthly_cftemp_F_bin${binsize}_`method'.dta", clear
                        /* use "${weather}monthly/era5_monthly_UScounty_1970_2019_cftemp_F_`method'.dta", clear */
                  }
                  else {
                        use "${temperature}`source'_UScounty_cftemp_F_bin${binsize}_year.dta", clear
                        /* use "${weather}monthly/era5_monthly_UScounty_1970_2019_cftemp_F.dta", clear */
                  } */
            
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

                              if "`method'" == "year" | "`method'" == "bayes" | "`method'" == "chebyshev" {
                                    * Compare no correction to cftemp
                                    cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare1(cftemp) method(`reg')
                                    graph export "${figures}real_outcomes/crime_`outcome'_`source'_`method'_`reg'.pdf", replace

                                    * Just no correction
                                    /* cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare1(none) method(`reg')
                                    graph export "${figures}real_outcomes/crime_`outcome'_`reg'_`source'_`method'.pdf", replace */
                              }

                              if "`method'" == "trends" {
                                    * Compare no correction to county-specific trends
                                    cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare1(trends, county_month#c.year) method(`reg')
                                    graph export "${figures}real_outcomes/crime_`outcome'_`source'_trends_`reg'.pdf", replace
                              }

                              if "`method'" == "5year" {
                                    * Compare no correction to county-5 year FEs
                                    cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare1(5year, countymonth5year year_month) method(`reg')
                                    graph export "${figures}real_outcomes/crime_`outcome'_`source'_5year_`reg'.pdf", replace
                              }

                              if "`method'" == "5year_bayes" {
                                    cftemp_plot rate_`outcome', $bins fe(county_month year_month) cluster(fips) compare1(cftemp) compare2(5year, countymonth5year year) method(`reg')
                                    graph export "${figures}real_outcomes/crime_`outcome'_`source'_5year_bayes_`reg'.pdf", replace
                              }
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

                              if "`method'" == "year" | "`method'" == "bayes" | "`method'" == "chebyshev" {
                                    cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare1(cftemp)
                                    graph export "${figures}real_outcomes/crops_`outcome'_`source'_`method'.pdf", replace

                                    * Just no correction
                                    /* cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare1(none)
                                    graph export "${figures}real_outcomes/crops_`outcome'_`source'_`method'_before.pdf", replace */
                              }

                              if "`method'" == "trends" {
                                    * Compare no correction to county-specific trends
                                    cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare1(trends, fips#c.year)
                                    graph export "${figures}real_outcomes/crops_`outcome'_`source'_trends.pdf", replace
                              }

                              if "`method'" == "5year" {
                                    * Compare no correction to county-5 year FEs
                                    cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare1(5year, county5year year)
                                    graph export "${figures}real_outcomes/crops_`outcome'_`source'_5year.pdf", replace
                              }

                              if "`method'" == "5year_bayes" {
                                    cftemp_plot log`outcome'Output, $bins fe(fips year) cluster(fips) compare1(cftemp) compare2(5year, county5year year)
                                    graph export "${figures}real_outcomes/crops_`outcome'_`source'_5year_bayes.pdf", replace
                              }
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
                                    if "`method'" == "year" | "`method'" == "bayes" | "`method'" == "chebyshev" {
                                          cftemp_plot `outcome', $bins fe(fips decade) cluster(fips) compare1(cftemp) method(`reg')
                                          graph export "${figures}real_outcomes/`outcome'_`source'_`method'_`reg'.pdf", replace

                                          * Just no correction
                                          cftemp_plot `outcome', $bins fe(fips decade) cluster(fips) compare1(none) method(`reg')
                                          graph export "${figures}real_outcomes/`outcome'_`source'_naive_`reg'.pdf", replace
                                    }

                                    if "`method'" == "trends" {
                                          * Compare no correction to county-specific trends
                                          cftemp_plot `outcome', $bins fe(fips decade) cluster(fips) compare1(trends, fips#c.decade) method(`reg')
                                          graph export "${figures}real_outcomes/`outcome'_`source'_trends_`reg'.pdf", replace
                                    }
                              }
                        }

                  restore
      }
}
