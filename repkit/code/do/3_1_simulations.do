/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: July 2025
ACTION: Runs all simulations.
*******************************************************************************
Set Up
*********************************/
args data repkit task
global data "`data'"
global repkit "`repkit'"
global task `task'

do "${repkit}code/do/0_setup.do"
/* global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/" */

log using "${log}3_1_simulations/3_1_simulations_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

display "`c(tmpdir)'"
ssc install ftools, replace
ssc install gtools, replace
ssc install reghdfe, replace
ssc install require, replace

/*********************************
Parallelize temperature data source and control methods
*********************************/
* Main
local sources  "era5"
local methods  "naive stateyearFE lag3 trends 5year year bayes chebyshev adapt"
local binforms "allbins extreme"
local binsizes "10"

* Robustness: alternative binsizes
local combo19 "era5 naive allbins 5"
local combo20 "era5 naive allbins 20"

* Robustness: alternative sources
local combo21 "prism_1950 naive allbins 10"
local combo22 "ghcn naive allbins 10"
local combo23 "era5_C adapt allbins 5"

* Simulation 1 with Counterfactual Control
local combo24 "era5 sim allbins 10"
local combo25 "era5 sim allbins 10"
local combo26 "era5 sim allbins 10"

* 5-year + bayes
local combo27 "era5 5year_bayes allbins 10"

* Emulator
local combo28 "era5_C year allbins 5"

* Count items in each dimension for existing permutations
local n_sources  : word count `sources'
local n_methods  : word count `methods'
local n_binforms : word count `binforms'
local n_binsizes : word count `binsizes'

* Calculate total tasks for existing permutations
local n_existing_tasks = `n_sources' * `n_methods' * `n_binforms' * `n_binsizes'

* Determine if this task is for existing permutations or specific combinations
if `task' <= `n_existing_tasks' {
      * Existing permutations
      local s_index  = ceil(`task' / (`n_binforms' * `n_methods' * `n_binsizes'))
      local temp1    = mod(`task'-1, (`n_binforms' * `n_methods' * `n_binsizes'))
      local b_index  = ceil((`temp1' + 1) / (`n_methods' * `n_binsizes'))
      local temp2    = mod(`temp1', (`n_methods' * `n_binsizes'))
      local m_index  = ceil((`temp2' + 1) / `n_binsizes')
      local bs_index = mod(`temp2', `n_binsizes') + 1

      local source  : word `s_index'  of `sources'
      local method  : word `m_index'  of `methods'
      local binform : word `b_index'  of `binforms'
      local binsize : word `bs_index' of `binsizes'
}
else {
      * Specific combinations
      local source = word("`combo`task''", 1)
      local method = word("`combo`task''", 2)
      local binform = word("`combo`task''", 3)
      local binsize = word("`combo`task''", 4)
}

* Print to verify
di "Slurm task `task': source=`source', method=`method', binform=`binform', binsize=`binsize'"

/*********************************
Add average annual temperature -- should be deleted later
*********************************/
* GHCN yearly averages
/* if "`source'" == "ghcn"{
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
if strpos("`source'", "era5") > 0 {
      /* use "${raw}countyLevel_USPanel_1970_2019.dta", clear
            //this uses ERA Land, not ERA 5

      drop if year > 2019 | year < 1970
      keep fips year avg_yearly_temp //avg_yearly_temp uses whole day avg not daytime avg
      replace avg_yearly_temp = (avg_yearly_temp * 9 / 5) + 32
      duplicates drop */

      use "${weather}countyannual_US_1970_2019.dta", clear //this comes from "${path}/DTA_US/countyLevel_US_1970_2019.dta", which is day level data converted to F then collapsed to annual mean
      if "`source'" == "era5_C" {
            replace avg_yearly_temp = (avg_yearly_temp - 32) * (5/9)
      }
} 

sum avg_yearly_temp
tempfile `source'_avgtemp
save ``source'_avgtemp', replace*/

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
local base_era5_C = 1980 // change below for emulator
local base_prism_1950 = 1960
local base_prism_1970 = 1980
local base_ghcn = 1980

local graph_neg1 "yscale(range(-6 2)) ylabel(-6(2)2)"
local graph_0 "yscale(range(-4 4)) ylabel(-4(2)4)"
local graph_1 "yscale(range(-2 6)) ylabel(-2(2)6)"

* Binning
if "`binsize'" == "5" local omit = 10
if "`binsize'" == "10" local omit = 6
if "`binsize'" == "20" local omit = 4

* Compare option: compare_sim2 = full option(s) passed to ado in sim 2 (e.g. compare1(...) or compare1(...) compare2(...))
local compare_sim1 "none"
local compare_sim2 "compare1(none)"
if strpos("`method'", "naive") == 0 {
      if strpos("`method'", "trends") > 0 {
            local compare_sim1 "naive trends, fips#c.year"
            local compare_sim2 "compare1(naive trends, fips#c.year)"
      }
      else if strpos("`method'", "stateyearFE") > 0 {
            local compare_sim1 "naive stateyear, stateyear fips"
            local compare_sim2 "compare1(naive stateyear, stateyear fips)"
      }
      else if strpos("`method'", "lag") > 0 {
            local compare_sim1 "naive lags, 3"
            local compare_sim2 "compare1(naive lags, 3)"
      }
      else if strpos("`method'", "5year_bayes") > 0 {
            local compare_sim1 "compare1(naive cftemp) compare2(5year, county5year year)"
            local compare_sim2 "compare1(naive cftemp) compare2(5year, county5year year)"
      }
      else if strpos("`method'", "5year") > 0 {
            local compare_sim1 "naive 5year, county5year year"
            local compare_sim2 "compare1(naive 5year, county5year year)"
      }
      else if strpos("`method'", "adapt") > 0 {
            local compare_sim1 "naive sim"
            local compare_sim2 "compare1(naive het, aboveMedian)"
      }
      else {
            local compare_sim1 "naive sim"
            local compare_sim2 "compare1(naive cftemp)"
      }
}

/*********************************
Main script
*********************************/
      * Counterfactual temperature controls
      if "`method'" == "bayes" | "`method'" == "5year_bayes" { // "`method'" == "year" |
            use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_bayes.dta", clear
            /* use "${weather}era5_UScounty_1970_2019_cftemp_F_`method'.dta", clear */
      }
      else if "`method'" == "chebyshev" {
            use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_chebyshev.dta", clear
      }
      * Reduced Form Methods
      else if "`source'" == "era5" & "`binsize'" == "10" {
            use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_year.dta", clear
            /* use "${weather}era5_UScounty_1970_2019_cftemp_F.dta", clear */
            /* use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_over100_naive.dta", clear */
      }
      * Alternative bin sizes
      else if "`source'" == "era5" & "`binsize'" != "10" {
            use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_naive.dta", clear
      }
      * Celsius
      else if "`source'" == "era5_C" {
            use "${temperature}era5_UScounty_cftemp_C_bin`binsize'_bayes.dta", clear
      }
      * Other data sources (PRISM, GHCN)
      else if "`source'" == "prism_1950" | "`source'" == "ghcn" {
            use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_naive.dta", clear
      }
      * Emulator
      else if `task' == 28 {
            local base_era5_C = 1960
            use "${temperature}era5_UScounty_cftemp_C_bin`binsize'_year_emu_1950_6hr_1deg", clear
            /* use "${temperature}era5_UScounty_cftemp_C_bin5_bayes.dta", clear */
            /* use "/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/era5_counts_all.dta", clear */
            /* use "/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/era5_counts_all_years.dta", clear */
            /* drop if year > 2010 */
      }

      xtset fips year

      * Merge average temps
      /* merge m:1 year fips using ``source'_avgtemp'
      keep if _merge == 3
      drop _merge */

      * add state information
      merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
      egen stateCode = group(state)
      drop if state == "AK" | state == "PR" | state == "HI"

      * state-year FE
      egen stateyear = group(state year)

      * create pre period temperature
      gen baselinePeriodTemp = avg_yearly_temp if year <= `base_`source''
      bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)
      sum baselinePeriodTemp

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
            if "`source'" == "era5" & "`method'" == "naive" & "`binsize'" == "10" {
                  foreach slope in 1 { //forval slope = -1(1)1
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, `slope') binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare1(none) fe(fips year) cluster(fips)
                  }
            }
            if  "`method'" == "sim" {
                  if `task' == 24 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare1(naive sim) fe(fips year) cluster(fips)
                        exit
                  }
                  if `task' == 25 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(quad, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare1(naive sim) fe(fips year) cluster(fips)
                        exit
                  }
                  if `task' == 26 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare1(naive sim) fe(fips year) cluster(fips) effect(50)
                        exit
                  }
            }
            
            ********************************* Simulations with real temperature data (sim2)
            * Linear version
            if "`source'" == "era5" & "`method'" == "naive" & "`binsize'" == "10" {
                  forval slope = -1(1)1 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, `slope') binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips) graph(`graph_`slope'')
                  }
            }
            else if "`source'" == "era5_C" {
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(5) lb(-10) ub(35) omit(8) `compare_sim2' fe(fips year) cluster(fips)
            }
            else { //everything including adaptation
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips) //graph(`graph_1')
            }

            * Extra spec (omit 7th bin) for adaptation
            if strpos("`method'", "adapt") > 0 & "`source'" != "era5_C" {
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(7) `compare_sim2' fe(fips year) cluster(fips)
            }

            * Everything except adaptation
            if "`source'" == "era5" & strpos("`method'", "adapt") <= 0 & "`binsize'" == "10" {
                  * Quadratic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(quad, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips)

                  * Cubic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(cubic, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips)

                  * Linear trend, real effect of 5 on both extreme bins
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips) effect(5)
            }
      }

      /*********************************
      Just the extreme bins
      *********************************/
      if "`binform'" == "extreme" {
            
            ********************************* Simulations with real temperature data (sim2)
            * Linear trends + bias table
            cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips) extreme bias

            if strpos("`method'", "adapt") <= 0 {
                  * Quadratic trends
                  /* cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(quad, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips) extreme

                  * Cubic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(cubic, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') `compare_sim2' fe(fips year) cluster(fips) extreme */
            }
      }

log close