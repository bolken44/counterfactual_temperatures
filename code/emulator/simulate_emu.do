/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: July 2025
ACTION: Runs all simulations.
*******************************************************************************
Set Up
*********************************/
args data home task
global data "`data'"
global home "`home'"
global task `task'

global emulator "${data}emulator/"
global simulations "${home}output/emulator/"
global temp "${data}emulator/temp/"
mkdir "${temp}"

log using "${home}log/emulator/simulate_emu_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Run ado files
*********************************/
global ado "${home}repkit/code/ado/"

adopath + "${ado}"
run "${ado}cftemp.ado"
run "${ado}cftemp_sim.ado"
run "${ado}cftemp_plot.ado"

/*********************************
Parallelize temperature data source and control methods
*********************************/
* Main
local sources  "era5"
local methods  "naive stateyearFE lag3 trends 5year" //  year bayes chebyshev adapt
local binforms "allbins extreme"
local binsizes "5"

local combo11 "era5 emu allbins 5"
local combo12 "era5 emu extreme 5"

* Robustness: alternative binsizes
/* local combo19 "era5 naive allbins 5"
local combo20 "era5 naive allbins 20"

* Robustness: alternative sources
local combo21 "prism_1950 naive allbins 10"
local combo22 "ghcn naive allbins 10"
local combo23 "era5_C adapt allbins 10"

* Simulation 1 with Counterfactual Control
local combo24 "era5 sim allbins 10"
local combo25 "era5 sim allbins 10"
local combo26 "era5 sim allbins 10" */

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
/* use "${emulator}avg_temp_day_cftemp.dta", clear

keep year fips avg_yearly_temp
keep if mod(year, 10) == 0

keep if inrange(year, 1970, 2019)

sum avg_yearly_temp
tempfile era5_avgtemp
save `era5_avgtemp', replace */

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
local base_era5 = 1960 // changed for emulator experiment
local base_era5_C = 1980
local base_prism_1950 = 1960
local base_prism_1970 = 1980
local base_ghcn = 1980

local graph_neg1 "yscale(range(-6 2)) ylabel(-6(2)2)"
local graph_0 "yscale(range(-4 4)) ylabel(-4(2)4)"
local graph_1 "yscale(range(-2 6)) ylabel(-2(2)6)"

* Binning
/* if "`binsize'" == "5" local omit = 10 */
/* if "`binsize'" == "10" local omit = 6
if "`binsize'" == "20" local omit = 4 */

global lb = -10
global ub = 35
local binsize = 5
local omit = 6

* Compare option
local compare1 = cond(strpos("`method'", "naive") > 0, "none", cond(strpos("`method'", "trends") > 0, "naive trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "naive stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "naive lags, 3", cond(strpos("`method'", "5year") > 0, "naive 5year, county5year year", "naive sim")))))

local compare2 = cond(strpos("`method'", "naive") > 0, "none", cond(strpos("`method'", "trends") > 0, "naive trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "naive stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "naive lags, 3", cond(strpos("`method'", "5year") > 0, "naive 5year, county5year year", cond(strpos("`method'", "adapt") > 0, "naive het, aboveMedian", "naive cftemp")))))) //different from sim 1 compare! cftemp instead of sim

/*********************************
Main script
*********************************/
      /* * Counterfactual temperature controls
      if "`method'" == "bayes" | "`method'" == "chebyshev" { // "`method'" == "year" |
            /* use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_`method'.dta", clear */
            use "${weather}era5_UScounty_1970_2019_cftemp_F_`method'.dta", clear
      }
      * Reduced Form Methods
      else if "`source'" == "era5" & "`binsize'" == "10" {
            /* use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_year.dta", clear */
            use "${weather}era5_UScounty_1970_2019_cftemp_F.dta", clear
            /* use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_over100_naive.dta", clear */
      }
      * Alternative bin sizes
      else if "`source'" == "era5" & "`binsize'" != "10" {
            use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_naive.dta", clear
      }
      * Other data sources
      else {
            /* use "${temperature}`source'_UScounty_cftemp_F_bin`binsize'_naive.dta", clear */
            if "`source'" == "ghcn" {
                  use "${weather}ghcn_UScounty_1968_2016_cftemp.dta", clear
            }
            else if "`source'" == "prism_1950" {
                  use "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta", clear
            }
            else if "`source'" == "era5_C" {
                  use "${weather}era5_UScounty_1970_2019_cftemp.dta", clear
            }
      } */

      use "${emulator}era5_counts_all.dta", clear

      /* keep if inrange(year, 1970, 2019) */
      xtset fips year
      cap drop _merge

      * Merge average temps
      /* merge 1:1 year fips using `era5_avgtemp'
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
            /* if "`source'" == "era5" & "`method'" == "naive" & "`binsize'" == "10" {
                  foreach slope in 1 { //forval slope = -1(1)1
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, `slope') binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(none) fe(fips year) cluster(fips)
                  }
            }
            if  "`method'" == "sim" {
                  if `task' == 24 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(naive sim) fe(fips year) cluster(fips)
                  }
                  if `task' == 25 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(quad, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(naive sim) fe(fips year) cluster(fips)
                  }
                  if `task' == 26 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(naive sim) fe(fips year) cluster(fips) effect(50)
                  }
            } */
            
            ********************************* Simulations with real temperature data (sim2)
            * Naive
            if "`source'" == "era5" & "`method'" == "naive" & "`binsize'" == "10" {
                  forval slope = -1(1)1 {
                        cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, `slope') binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips) graph(`graph_`slope'')
                  }
            }
            else if "`source'" == "era5_C" {
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(5) lb(-10) ub(35) omit(8) compare(`compare2') fe(fips year) cluster(fips)
            }
            else { //everything including adaptation
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips) //graph(`graph_1')
            }

            * Extra spec (omit 7th bin) for adaptation
            if strpos("`method'", "adapt") > 0 {
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(7) compare(`compare2') fe(fips year) cluster(fips)
            }

            * Everything except adaptation
            if "`source'" == "era5" & strpos("`method'", "adapt") <= 0 & "`binsize'" == "10" {
                  * Quadratic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(quad, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips)

                  * Cubic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(cubic, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips)

                  * Linear trend, real effect of 5 on both extreme bins
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips) effect(5)
            }
      }

      /*********************************
      Just the extreme bins
      *********************************/
      if "`binform'" == "extreme" {
            
            ********************************* Simulations with real temperature data (sim2)
            * Linear trends + bias table
            cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(lin, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips) extreme bias

            if strpos("`method'", "adapt") <= 0 {
                  * Quadratic trends
                  /* cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(quad, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips) extreme
                  * Cubic trends
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(cubic, 1) binsize(`binsize') lb($lb) ub($ub) omit(`omit') compare(`compare2') fe(fips year) cluster(fips) extreme */
            }
      }

log close