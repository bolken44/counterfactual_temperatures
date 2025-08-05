/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: June 2025 - this code parallelizes reformed_bias_table.do for the cluster.
ACTION: Creates tables to compare binning bias across different cftemp versions.
*******************************************************************************/

/*********************************
Set Up SLURM
*********************************/
** Get Slurm ID
args task
local task = real("`task'")
global task = `task'

log using "${home}log/4_1_bias_table/row_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Run Setup File
*********************************/
do "${do}0_setup.do"

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
local title_naive = "No correction"
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

local title_era5_F = "ERA 5"
local base_era5_F = 1980
local title_schlenker_F = "PRISM"
local base_schlenker_F = 1960
local title_prism_1970 = "PRISM (1970-2019)"
local base_prism_1970 = 1980
local title_ghcn_ext = "GHCN"
local base_ghcn_ext = 1980

//start of the loop
global source = "`source'"
global method = "`method'"

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
replace year = year - `r(min)' + 1

* State-year FE
egen stateyear = group(state year)

* County - 5 year FEs
gen year_bin5 = floor(year/5)*5
egen county5year = group(fips year_bin5)

drop _merge year_bin5 avg_yearly_temp

******************************* Simulation 2 coefficient and SE, trend in Y
local compare = cond(strpos("`method'", "naive") > 0, "none", cond(strpos("`method'", "trends") > 0, "trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "lags, 3", cond(strpos("`method'", "5year") > 0, "5year, county5year year", "cftemp"))))) //different from sim 1 compare! cftemp instead of sim

cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(linear, 1) $bins compare(`compare') fe(fips year) cluster(fips) extreme bias

foreach bin in under_`lb_str' over_`ub_str' {
      local sim2_coef_`bin' = "${coef_p500_1_`bin'}"
      local sim2_ci_`bin' = "[${coef_p25_1_`bin'}, ${coef_p975_1_`bin'}]"
      local sim2_tstat_`bin' = "${tstat_p500_1_`bin'}"
      local sim2_tstat_ci_`bin' = "[${tstat_p25_1_`bin'}, ${tstat_p975_1_`bin'}]"

      local bias_`bin' = "" //initialize
      local slope_`bin' = ${slope_`bin'}
      local resid_`bin' = ${resid_`bin'}
}
local sigma_T0 = ${sigma_T0}

* Finite T case
foreach bin in under_`lb_str' over_`ub_str' {
      
      * Initialize
      local `source'_row_`bin' = "``source'_row_`bin'' & \multirow{2}{*}{`title_`method''}"
      local second_row = " &"

      * Fill in
      local `source'_row_`bin' = "``source'_row_`bin'' & `sim2_coef_`bin'' & `sim2_tstat_`bin'' & ${slope_`bin'_str} & ${resid_`bin'_str} & ${coef_1_Y_str} & ${bias2_`bin'}"
      local second_row = "`second_row' & `sim2_ci_`bin'' & `sim2_tstat_ci_`bin'' & ${trend_ci_`bin'} & ${coef_1_Y_ci} &"
      
      * Conjoin first and second rows
      local `source'_row_`bin' = "``source'_row_`bin'' \\ `second_row' \\"
}

local `source'_row_under_`lb_str' = "\midrule \multirow{50}{*}{\shortstack{`title_`source'' \\ \(\sigma^2_{T_0} = ${sigma2_T0_str}\)}} & \textit{Under 10 Bin} \\ ``source'_row_under_`lb_str''"

/*********************************
Export as Latex File
*********************************/
dis "``source'_row_under_`lb_str''"
dis "``source'_row_over_`ub_str''"

file open cftemp_`task'_`lb_str' using "${intermediate}cftemp_comp_`source'_`task'_under_`lb_str'.tex", write replace
file write cftemp_`task'_`lb_str' ///
      "``source'_row_under_`lb_str''" _n
file close cftemp_`task'_`lb_str'

file open cftemp_`task'_`ub_str' using "${intermediate}cftemp_comp_`source'_`task'_over_`ub_str'.tex", write replace
file write cftemp_`task'_`ub_str' ///
      "``source'_row_over_`ub_str''" _n
file close cftemp_`task'_`ub_str'