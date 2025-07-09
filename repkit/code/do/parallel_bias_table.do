/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: June 2025 - this code parallelizes reformed_bias_table.do for the cluster.
ACTION: Creates tables to compare binning bias across different cftemp versions.
*******************************************************************************/

clear all
set more off

global home "/orcd/home/002/hnaka24/climate/"
global output "${home}output/"

global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/"

** Get Slurm ID
args task
local task = real("`task'")
global task = `task'

log using "${home}log/bias_table/row_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

********************************************************************************
** Regressors
********************************************************************************
adopath + "${home}/cftemp"
run "${home}/cftemp/cftemp_sim.ado"

/* ssc install ereplace, replace
ssc install reghdfe, replace
ssc install ftools, replace */

* Declare which one
local sources "era5_F schlenker_F ghcn_ext prism_1970"
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

********************************************************************************
** ADD WEATHER DATA
********************************************************************************
if "`source'" == "era5_F" {
      local data_era5 = "${weather}era5_UScounty_1970_2019_cftemp.dta"
      local data_month_era5 = "${weather}era5_monthly_UScounty_1970_2019_cftemp.dta"
      local bins_era5 = "binsize(5) lb(-10) ub(35) omit(6)"

      local data_era5_F_year = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
      local data_month_era5_F_year = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"
      local bins_era5_F = "binsize(10) lb(10) ub(90) omit(6)"

      local data_era5_F_year_bayes = "${weather}era5_UScounty_1970_2019_cftemp_F_bayes.dta"
      local data_month_era5_F_year_bayes = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_bayes.dta"

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

      * ERA 5 yearly averages
      /* use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear
      /* keep if fips == 4013 | fips == 25025 */
      keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
      reshape long avg_temp_daytime avg_temp_day, i(fips year latitude longitude month) j(day)
      drop latitude longitude
      drop if avg_temp_daytime == .

      replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32

      collapse (mean) avg_yearly_temp = avg_temp_daytime, by(fips year)

      save "${weather}countyannual_US_1970_2019.dta", replace */
      local era5_F_avgtemp "${weather}countyannual_US_1970_2019.dta"

      local title_era5_F = "ERA 5"
      local base_era5_F = 1980
}

if "`source'" == "ghcn_ext" {
      local data_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp.dta"
      local prcp_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp_prcp.dta"
      local data_month_ghcn = "${weather}ghcn_monthly_UScounty_1968_2002_cftemp.dta"
      local prcp_month_ghcn = "${weather}ghcn_monthly_UScounty_1968_2002_cftemp_prcp.dta"
      local bins_ghcn = "binsize(10) lb(10) ub(90) omit(6)"

      local data_ghcn_ext_year = "${weather}ghcn_UScounty_1968_2016_cftemp.dta"
      local prcp_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp_prcp.dta"
      local data_month_ghcn_ext_year = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp.dta"
      local prcp_month_ghcn_ext = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_prcp.dta"
      local bins_ghcn_ext = "binsize(10) lb(10) ub(90) omit(6)"

      local data_ghcn_ext_year_bayes = "${weather}ghcn_UScounty_1968_2016_cftemp_F_bayes.dta"
      local data_month_ghcn_ext_year_bayes = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_F_bayes.dta"

      local data_ghcn_ext_avgtrend = "${weather}ghcn_UScounty_1968_2016_cftemp_F_avgtrend.dta"
      local data_month_ghcn_ext_avgtrend = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_F_avgtrend.dta"

      local data_ghcn_ext_avgtrend_bayes = "${weather}ghcn_UScounty_1968_2016_cftemp_F_avgtrend_bayes.dta"
      /* local data_month_ghcn_ext_avgtrend_bayes = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_F_avgtrend_bayes.dta" */

      local data_ghcn_ext_chebyshev = "${weather}ghcn_UScounty_1968_2016_cftemp_F_chebyshev.dta"
      local data_month_ghcn_ext_chebyshev = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_F_chebyshev.dta"

      local data_ghcn_ext_splines = "${weather}ghcn_UScounty_1968_2016_cftemp_F_splines.dta"
      local data_month_ghcn_ext_splines = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_F_splines.dta"

      local data_ghcn_ext_aggregate = "${weather}ghcn_UScounty_1968_2016_cftemp_F_aggregate.dta"
      local data_month_ghcn_ext_aggregate = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_F_aggregate.dta"

      * GHCN yearly averages
      use "${weather}ghcn_UScountylevel_1968_2016.dta", clear
      /* drop if year > 2016 | year < 1968 */

      gen tmean = (TMAX + TMIN) / 2
      bysort fips year: egen avg_yearly_temp = mean(tmean)
      keep fips year avg_yearly_temp
      duplicates drop

      tempfile ghcn_ext_avgtemp
      save `ghcn_ext_avgtemp'

      local title_ghcn_ext = "GHCN"
      local base_ghcn_ext = 1980
}

if "`source'" == "schlenker_F" {
      local data_schlenker = "${weather}schlenker_UScounty_1950_2019_cftemp.dta"
      local data_month_schlenker = "${weather}schlenker_UScounty_1950_2019_cftemp.dta"
      local bins_schlenker = "binsize(5) lb(-10) ub(35) omit(6)"

      local data_schlenker_F_year = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
      local data_month_schlenker_F_year = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
      local bins_schlenker_F = "binsize(10) lb(10) ub(90) omit(6)"

      local data_schlenker_F_year_bayes = "${weather}schlenker_UScounty_1950_2019_cftemp_F_bayes.dta"
      /* local data_month_schlenker_F_year_bayes = "${weather}schlenker_monthly_UScounty_1950_2019_cftemp_F_bayes.dta" */

      local data_schlenker_F_avgtrend = "${weather}schlenker_UScounty_1950_2019_cftemp_F_avgtrend.dta"
      local data_month_schlenker_F_avgtrend = "${weather}schlenker_monthly_UScounty_1950_2019_cftemp_F_avgtrend.dta"

      local data_schlenker_F_avgtrend_bayes = "${weather}schlenker_UScounty_1950_2019_cftemp_F_avgtrend_bayes.dta"
      /* local data_month_schlenker_F_avgtrend_bayes = "${weather}schlenker_monthly_UScounty_1950_2019_cftemp_F_avgtrend_bayes.dta" */

      local data_schlenker_F_chebyshev = "${weather}schlenker_UScounty_1950_2019_cftemp_F_chebyshev.dta"
      /* local data_month_schlenker_F_chebyshev = "${weather}schlenker_monthly_UScounty_1950_2019_cftemp_F_chebyshev.dta" */

      local data_schlenker_F_splines = "${weather}schlenker_UScounty_1950_2019_cftemp_F_splines.dta"
      local data_month_schlenker_F_splines = "${weather}schlenker_monthly_UScounty_1950_2019_cftemp_F_splines.dta"

      local data_schlenker_F_aggregate = "${weather}schlenker_UScounty_1950_2019_cftemp_F_aggregate.dta"
      /* local data_month_schlenker_F_aggregate = "${weather}schlenker_monthly_UScounty_1950_2019_cftemp_F_aggregate.dta" */

      * PRISM yearly averages (1950-2019)
      use "${pool}data/appended.dta", clear
      /* drop if year > 2019 | year < 1970 */

      replace tMax = (tMax * 9 / 5) + 32
      bysort fips year: egen avg_yearly_temp = mean(tMax)
      keep fips year avg_yearly_temp
      duplicates drop

      tempfile schlenker_F_avgtemp
      save `schlenker_F_avgtemp'

      local title_schlenker_F = "PRISM"
      local base_schlenker_F = 1960
}

if "`source'" == "prism_1970" {
      local data_prism_1970_year = "${weather}schlenker_UScounty_1970_2019_cftemp_F_year.dta"
      local data_month_prism_1970_year = "${weather}schlenker_UScounty_1970_2019_cftemp_F_year.dta"
      local bins_prism_1970 = "binsize(10) lb(10) ub(90) omit(6)"

      local data_prism_1970_year_bayes = "${weather}schlenker_UScounty_1970_2019_cftemp_F_bayes.dta"
      /* local data_month_prism_1970_year_bayes = "${weather}schlenker_monthly_UScounty_1970_2019_cftemp_F_bayes.dta" */

      local data_prism_1970_avgtrend = "${weather}schlenker_UScounty_1970_2019_cftemp_F_avgtrend.dta"
      local data_month_prism_1970_avgtrend = "${weather}schlenker_monthly_UScounty_1970_2019_cftemp_F_avgtrend.dta"

      local data_prism_1970_avgtrend_bayes = "${weather}schlenker_UScounty_1970_2019_cftemp_F_avgtrend_bayes.dta"
      /* local data_month_prism_1970_avgtrend_bayes = "${weather}schlenker_monthly_UScounty_1970_2019_cftemp_F_avgtrend_bayes.dta" */

      local data_prism_1970_chebyshev = "${weather}schlenker_UScounty_1970_2019_cftemp_F_chebyshev.dta"
      /* local data_month_prism_1970_chebyshev = "${weather}schlenker_monthly_UScounty_1970_2019_cftemp_F_chebyshev.dta" */

      local data_prism_1970_splines = "${weather}schlenker_UScounty_1970_2019_cftemp_F_splines.dta"
      local data_month_prism_1970_splines = "${weather}schlenker_monthly_UScounty_1970_2019_cftemp_F_splines.dta"

      local data_prism_1970_aggregate = "${weather}schlenker_UScounty_1970_2019_cftemp_F_aggregate.dta"
      /* local data_month_prism_1970_aggregate = "${weather}schlenker_monthly_UScounty_1970_2019_cftemp_F_aggregate.dta" */

      * PRISM yearly averages (1970-2019)
      use "${pool}data/appended.dta", clear
      drop if year > 2019 | year < 1970

      replace tMax = (tMax * 9 / 5) + 32
      bysort fips year: egen avg_yearly_temp = mean(tMax)
      keep fips year avg_yearly_temp
      duplicates drop
      tempfile prism_1970_avgtemp
      save `prism_1970_avgtemp'

      local title_prism_1970 = "PRISM (1970-2019)"
      local base_prism_1970 = 1980
}

* add state information
preserve
	import delimited "${pool}data/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

* set seed
set seed 1642
********************************************************************************
** RUN
********************************************************************************
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

local binsize = 10
local lb = 10
local ub = 90

//start of the loop
global source = "`source'"
global method = "`method'"

local data_`source'_naive = "`data_`source'_year'"
local data_`source'_trends = "`data_`source'_year'"
local data_`source'_stateyearFE = "`data_`source'_year'"
local data_`source'_lag3 = "`data_`source'_year'"
local data_`source'_5year = "`data_`source'_year'"

local row = "`row' \midrule \multirow{8}{*}{`title_`source''}"
      
      
* Prepare dataset
use "`data_`source'_`method''", clear
dis _N

* Restrict time period
/* keep if inrange(year,1970,2019) */

* Merge average temps
merge m:1 year fips using ``source'_avgtemp'
keep if _merge == 3
drop _merge

* add state information
merge m:1 fips using `fipsToState'
drop if _merge != 3
drop if state == "AK" | state == "PR" | state == "HI"

* create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= `base_`source''
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
/* gen agno = year */
sum year
replace year = year - `r(min)' + 1 //why +1? Ask Cristine

* state-year FE
egen stateyear = group(state year)

* county - 5 year FEs
gen year_bin5 = floor(year/5)*5
egen county5year = group(fips year_bin5)

/* drop if fips > 1500 */
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

******************************* Simulation 1 coefficient and SE
/* local compare = cond(strpos("`method'", "naive") > 0, "none", cond(strpos("`method'", "trends") > 0, "trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "lags, 3", cond(strpos("`method'", "5year") > 0, "5year, county5year year", "sim")))))

if inlist("`method'", "naive", "stateyearFE", "lag3", "trends", "5year", "year") {
      cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(1) outcome(linear, 1) `bins_`source'' compare(`compare') fe(fips year) cluster(fips) extreme

      foreach bin in under_`lb_str' over_`ub_str' {
            local sim1_coef_`bin' = "${coef_1_`bin'}"
            local sim1_ci_`bin' = "[${p25_1_`bin'}, ${p975_1_`bin'}]"
      }
}
else {
      foreach bin in under_`lb_str' over_`ub_str' {
            local sim1_coef_`bin' = ""
            local sim1_ci_`bin' = ""
      }
} */

******************************* Simulation 2 coefficient and SE, trend in Y
local compare = cond(strpos("`method'", "naive") > 0, "none", cond(strpos("`method'", "trends") > 0, "trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "lags, 3", cond(strpos("`method'", "5year") > 0, "5year, county5year year", "cftemp"))))) //different from sim 1 compare! cftemp instead of sim

cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(linear, 1) `bins_`source'' compare(`compare') fe(fips year) cluster(fips) extreme bias

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

******************************* Implied bias (infinite T)
* Under bin
/* local denom_under_`lb_str' = (`slope_under_`lb_str'')^2 + ///
                  ((`slope_over_`ub_str'')^2 * `resid_under_`lb_str'' / `resid_over_`ub_str'') + ///
                  (`resid_under_`lb_str'' / `sigma_T0'^2)
local bias_under_`lb_str' : display %9.0g `slope_under_`lb_str'' / `denom_under_`lb_str''
local bias_under_`lb_str' = "`bias_under_`lb_str''" + "\omega_Y"

local omegaratio_under_`lb_str' : display %9.0g (`slope_over_`ub_str'')^2 * `resid_under_`lb_str'' / `resid_over_`ub_str''
local varratio_under_`lb_str' : display %9.0g `resid_under_`lb_str'' / `sigma_T0'^2

* Over bin
local denom_over_`ub' = (`slope_over_`ub_str'')^2 + ///
                  ((`slope_under_`lb_str'')^2 * `resid_over_`ub_str'' / `resid_under_`lb_str'') + ///
                  (`resid_over_`ub_str'' / `sigma_T0'^2)

local bias_over_`ub_str' : display %9.0g `slope_over_`ub_str'' / `denom_over_`ub_str''
local bias_over_`ub_str' = "`bias_over_`ub_str''" + "\omega_Y"

local omegaratio_over_`ub_str' : display %9.0g  (`slope_under_`lb_str'')^2 * `resid_over_`ub_str'' / `resid_under_`lb_str''
local varratio_over_`ub_str' : display %9.0g `resid_over_`ub_str'' / `sigma_T0'^2 */

******************************* Implied bias (finite T)
* Variance of the bins
/* foreach bin in under_`lb_str' over_`ub_str' {
      sum real_`bin'
      local sigma_`bin' = r(sd)
}

* Under bin
local num_C1 = (`slope_over_`ub_str'')^2 * `sigma_T0'^2 + `resid_over_`ub_str'' + 0.0012 * `sigma_over_`ub_str''^2
local num_C2 = `slope_under_`lb_str'' * `sigma_T0'^2
local num_C3 = `slope_under_`lb_str'' * `slope_over_`ub_str'' * `sigma_T0'^2
local num_C4 = `slope_over_`ub_str'' * `sigma_T0'^2
local num_C_all = `num_C1' * `num_C2' - `num_C3' * `num_C4'

* Over bin
local num_H1 = (`slope_under_`lb_str'')^2 * `sigma_T0'^2 + `resid_under_`lb_str'' + 0.0012 * `sigma_under_`lb_str''^2
local num_H2 = `slope_over_`ub_str'' * `sigma_T0'^2
local num_H3 = `slope_over_`ub_str'' * `slope_under_`lb_str'' * `sigma_T0'^2
local num_H4 = `slope_under_`lb_str'' * `sigma_T0'^2
local num_H_all = `num_H1' * `num_H2' - `num_H3' * `num_H4'

* Denominators
local denom_C = `num_H1' * `num_C1' - (`num_C3')^2
local denom_H = `num_C1' * `num_H1' - (`num_H3')^2
dis $coef_1_Y

* Bias
local bias2_under_`lb_str' = string(`num_C_all' * $coef_1_Y / `denom_C', "%9.0g")
local bias2_over_`ub_str'= string(`num_H_all' * $coef_1_Y / `denom_H', "%9.0g")
dis "`bias2_over_`ub_str''" */

******************************* Create string

* Large T case
/* foreach bin in under_`lb_str' over_`ub_str' {
      local `source'_row_`bin' = "``source'_row_`bin'' & \multirow{2}{*}{`title_`method''}"
      local `source'_row = "``source'_row' & `sim1_coef_`bin'' & `sim2_coef_`bin'' & `slope_`bin'' & ${resid_`bin'_str} & `bias_`bin''"
      local second_row = "`second_row' & `sim1_ci_`bin'' & `sim2_ci_`bin'' & [`lb_`bin'', `ub_`bin''] & &"
} */

* Finite T case
foreach bin in under_`lb_str' over_`ub_str' {
      
      * Initialize
      local `source'_row_`bin' = "``source'_row_`bin'' & \multirow{2}{*}{`title_`method''}"
      local second_row = " &"

      * Fill in
      local `source'_row_`bin' = "``source'_row_`bin'' & `sim2_coef_`bin'' & `sim2_tstat_`bin'' & ${slope_`bin'_str} & ${resid_`bin'_str} & ${coef_1_Y_str} & ${bias2_`bin'}" // & `sim1_coef_`bin''
      local second_row = "`second_row' & `sim2_ci_`bin'' & `sim2_tstat_ci_`bin'' & ${trend_ci_`bin'} & ${coef_1_Y_ci} &" // & `sim1_ci_`bin''
      
      * Conjoin first and second rows
      local `source'_row_`bin' = "``source'_row_`bin'' \\ `second_row' \\"
}


******************************* Parallel Table
/* local row = "`row' & `title_`method''"
dis "`row'" */

* Large T case
/* local formula = "Dataset & \multicolumn{1}{c}{Method}& \(\omega_C\) & \(\omega_C^2\) & \(\omega_H^2 \frac{\sigma_{e_c}^2}{\sigma_{e_H}^2}\) & \(\frac{\sigma_{e_c}^2}{\sigma_{T_0}^2}\) & Bias & \(\omega_H\) & \(\omega^2_H\) & \(\omega^2_C\) \(\frac{\sigma^2_{e_H}}{\sigma^2_{e_C}}\) & \(\frac{\sigma^2_{e_H}}{\sigma^2_{T_0}}\) & Bias \\"
foreach bin in under_`lb_str' over_`ub_str' {
      local row = "`row' & ${slope_`bin'_str} & `${slope2_`bin'_str}' & `omegaratio_`bin'' & `varratio_`bin'' & `bias_`bin''"
} */

* Finite T case
/* local formula = "Dataset & \multicolumn{1}{c}{Method} & \(\text{Term 1}_C\) & \(\text{Term 2}_C\) & \(\text{Term 3}_C\) & \(\text{Term 4}_C\) & \(\text{Num}_C\) & \(\text{Denom}_C\) & Bias & \(\text{Term 1}_H\) & \(\text{Term 2}_H\) & \(\text{Term 3}_H\) & \(\text{Term 4}_H\) & \(\text{Num}_H\) & \(\text{Denom}_H\) & Bias \\"
foreach bin in C H {
      local name = cond("`bin'" == "C", "under_`lb_str'", "over_`ub_str'")

      foreach term in num_`bin'1 num_`bin'2 num_`bin'3 num_`bin'4 num_`bin'_all denom_`bin' {
            local `term' = string(``term'', "%9.0g")
      }

      local row = "`row' & `num_`bin'1' & `num_`bin'2' & `num_`bin'3' & `num_`bin'4' & `num_`bin'_all' & `denom_`bin'' & `bias2_`name''"
} */

/* local row = "`row' \\" */

local `source'_row_under_`lb_str' = "\midrule \multirow{50}{*}{\shortstack{`title_`source'' \\ \(\sigma^2_{T_0} = ${sigma2_T0_str}\)}} & \textit{Under 10 Bin} \\ ``source'_row_under_`lb_str''"

dis "``source'_row_under_`lb_str''"
dis "``source'_row_over_`ub_str''"

file open cftemp_`task'_`lb_str' using "${output}/bindev/cftemp_comp_`source'_`task'_under_`lb_str'.tex", write replace
file write cftemp_`task'_`lb_str' ///
      "``source'_row_under_`lb_str''" _n
file close cftemp_`task'_`lb_str'

file open cftemp_`task'_`ub_str' using "${output}/bindev/cftemp_comp_`source'_`task'_over_`ub_str'.tex", write replace
file write cftemp_`task'_`ub_str' ///
      "``source'_row_over_`ub_str''" _n
file close cftemp_`task'_`ub_str'

* Write bias table
/* file open bias using "${output}/bindev/cftemp_bias_formula_new.tex", write replace
file write bias ///
      "\clearpage" _n ///
      "\thispagestyle{empty}" _n ///
      "\newgeometry{top=0.1in, bottom=0.1in, left=0.4in, right=0.4in}" _n ///
      "\begin{landscape}" _n ///
      "\begin{table}[htb]" _n ///
      "\centering" _n ///
      "\caption{Comparison of Different \texttt{cftemp} Methods - Terms in the Bias Formula}" _n ///
      "\label{cftemp-comp}" _n ///
      "\begin{threeparttable}" _n ///
      "\scalebox{0.75}{" _n ///
      "\begin{tabular}{llcccccccccccccc}" _n ///
      "\toprule" _n ///
      " & & \multicolumn{7}{c}{Under 10 Bin} & \multicolumn{7}{c}{Over 90 Bin} \\" _n ///
      "\cmidrule(lr){3-9} \cmidrule(lr){10-16}" _n ///
      "`formula'" _n ///
      "\midrule" _n ///
      "`row'" _n ///
      "\hline \hline" _n ///
      "\end{tabular}" _n ///
      "}" _n ///
      "\begin{tablenotes}" _n ///
      "\footnotesize \textit{Notes:} All temperatures are in \degree F. The sample period is 1970-2019 for ERA Land 5, 1950-2019 for PRISM, and 1968-2016 for GHCN." _n ///
      "\end{tablenotes}" _n ///
      "\end{threeparttable}" _n ///
      "\end{table}" _n ///
      "\end{landscape}" _n ///
      "\restoregeometry" _n
file close bias */