/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: June 2025 - this code parallelizes sim2_power.do
*******************************************************************************
Set Up
*********************************/
** Get Slurm ID and paths
args task data repkit
local task = real("`task'")
global task = `task'
global data "`data'"
global repkit "`repkit'"

** Run setup file
do "${repkit}code/do/0_setup.do"

** Log
log using "${log}4_2_power_table/row_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Select Dataset and Method to Run
*********************************/
* Declare which one
local sources "era5 prism_1950 prism_1970 ghcn"
local methods "naive stateyearFE lag3 trends 5year year year_bayes avgtrend avgtrend_bayes chebyshev splines aggregate"

* Compute the total number of methods
local n_methods : word count `methods'

* Determine source and method index from task ID
local s_index = ceil(`task' / `n_methods')
local m_index = mod(`task'-1, `n_methods') + 1

* Get the actual values
local source : word `s_index' of `sources'
local method : word `m_index' of `methods'

* Print to verify
di "Slurm task `task': source=`source', method=`method'"

/*********************************
Locals
*********************************/
local title_era5_F = "ERA 5"
local title_schlenker_F = "PRISM"
local title_prism_1970 = "PRISM (1970-2019)"
local title_ghcn_ext = "GHCN"

local sample_era5_F = "The sample period is 1970-2019 for ERA Land 5."
local sample_schlenker_F = "The sample period is 1950-2019 for this version of PRISM."
local sample_prism_1970 = "The sample period is 1970-2019 for this version of PRISM."
local sample_ghcn_ext = "The sample period is 1970-2016 for GHCN."

local base_era5_F = 1980
local base_schlenker_F = 1960
local base_prism_1970 = 1980
local base_ghcn_ext = 1980

local title_naive = "No correction"
local title_adapt0 = "No correction (Cold Counties)"
local title_adapt1 = "No correction (Hot Counties)"
local title_stateyearFE = "State-Year Fixed Effects"
local title_lag3 = "With 3 Lags"
local title_trends = "County-Specific Linear Trends"
local title_5year = "County-5 Year Fixed Effects"
local title_year = "Lin. in Year"
local title_year_bayes = "Lin. in Year + Bayes"
local title_avgtrend = "Lin. in Natl Avg"
local title_avgtrend_bayes = "Lin. in Natl Avg + Bayes"
local title_splines = "Splines in Year"
local title_chebyshev = "Chebyshev"
local title_aggregate = "Aggregate \(\pm\)5 Years"

local binsize = 10
local lb = 10
local ub = 90

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
Run
*********************************/
* Prepare dataset
use "${temperature}`source'_cftemp_F_`method'.dta", clear
dis _N

* Add state information
merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
drop if _merge != 3
drop if state == "AK" | state == "PR" | state == "HI"

* Create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= `base_`source''
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* Create numeric variable for year
sum year
replace year = year - `r(min)' + 1 //why +1? Ask Cristine

* State-year FE
egen stateyear = group(state year)

* County - 5 year FEs
gen year_bin5 = floor(year/5)*5
egen county5year = group(fips year_bin5)

drop _merge year_bin5 avg_yearly_temp

******************************* Binning
* Bin for below lower bound
local lb_str = cond(`lb' < 0, "n`=abs(`lb')'", "`lb'") //to create the string "n#" for negative numbers
local names_bins = "under_`lb_str'"

* Loop through the middle bins
local ub_bin = `ub'-`binsize'
forvalues start = `lb'(`binsize')`ub_bin' {
      local end = `start' + `binsize'
      local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
      local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")

      local names_bins = "`names_bins' `start_label'_`end_label'"
}

* Bin for above upper bound
local ub_str = cond(`ub' < 0, "n`=abs(`ub')'", "`ub'") //to name the bin real_over_`ub'
local names_bins = "`names_bins' over_`ub_str'"

******************************* Simulation 2 coefficient and SE, trend in Y
local compare = cond(strpos("`method'", "naive") > 0 | strpos("`method'", "adapt") > 0, "none", cond(strpos("`method'", "trends") > 0, "trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "lags, 3", cond(strpos("`method'", "5year") > 0, "5year, county5year year", "cftemp"))))) //different from sim 1 compare! cftemp instead of sim

* Initialize
foreach bin in under_`lb_str' over_`ub_str' {
      local `source'_row_`bin' = "``source'_row_`bin'' & \multirow{2}{*}{`title_`method''}"
      local second_row_`bin' = " &"
}

* Loop through powers
foreach power in linear quadratic cubic {
      cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(`power', 1) $bins compare(`compare') fe(fips year) cluster(fips) extreme

      foreach bin in under_`lb_str' over_`ub_str' {

            * Fill in from globals passed from cftemp_sim
            local `source'_row_`bin' = "``source'_row_`bin'' & ${coef_p500_1_`bin'} & ${tstat_p500_1_`bin'}"
            local second_row_`bin' = "`second_row_`bin'' & [${coef_p25_1_`bin'}, ${coef_p975_1_`bin'}] & [${tstat_p25_1_`bin'}, ${tstat_p975_1_`bin'}]"
      }
}

* Conjoin first and second rows
foreach bin in under_`lb_str' over_`ub_str' {
      local `source'_row_`bin' = "``source'_row_`bin'' \\ `second_row_`bin'' \\"
}

local `source'_row_under_`lb_str' = "\midrule \multirow{50}{*}{`title_`source''} & \textit{Under 10 Bin} \\ ``source'_row_under_`lb_str''"

/*********************************
Export as Latex File
*********************************/
dis "``source'_row_under_`lb_str''"
dis "``source'_row_over_`ub_str''"

file open power_`task'_`lb_str' using "${intermediate}power_table_`source'_`task'_under_`lb_str'.tex", write replace
file write power_`task'_`lb_str' ///
      "``source'_row_under_`lb_str''" _n
file close power_`task'_`lb_str'

file open power_`task'_`ub_str' using "${intermediate}power_table_`source'_`task'_over_`ub_str'.tex", write replace
file write power_`task'_`ub_str' ///
      "``source'_row_over_`ub_str''" _n
file close power_`task'_`ub_str'