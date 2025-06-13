/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: June 2025 - this is a reformation of bias_table.do that embeds code
to calculate omega_Y into the simulation ado file.
ACTION: Creates tables to compare binning bias across different cftemp versions.
*******************************************************************************/

clear all
set more off

ssc install ppmlhdfe
ssc install ereplace

global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

log using "${path}Haru/log/power_table1.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

********************************************************************************
** Regressors
********************************************************************************
adopath + "${path}/Haru/cftemp"
run "${path}/Haru/cftemp/cftemp_sim.ado"

********************************************************************************
** ADD WEATHER DATA
********************************************************************************
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


* GHCN yearly averages
/* use "${path}Haru/processed/ghcn_UScountylevel_1968_2016.dta", clear
/* drop if year > 2016 | year < 1968 */

gen tmean = (TMAX + TMIN) / 2
bysort fips year: egen avg_yearly_temp = mean(tmean)
keep fips year avg_yearly_temp
duplicates drop

tempfile ghcn_ext_avgtemp
save `ghcn_ext_avgtemp'

* PRISM yearly averages (1950-2019)
use "${path}Haru/data/PRISM_Schlenker/appended.dta", clear
/* drop if year > 2019 | year < 1970 */

replace tMax = (tMax * 9 / 5) + 32
bysort fips year: egen avg_yearly_temp = mean(tMax)
keep fips year avg_yearly_temp
duplicates drop

tempfile schlenker_F_avgtemp
save `schlenker_F_avgtemp' */

* PRISM yearly averages (1970-2019)
use "${path}Haru/data/PRISM_Schlenker/appended.dta", clear
drop if year > 2019 | year < 1970

replace tMax = (tMax * 9 / 5) + 32
bysort fips year: egen avg_yearly_temp = mean(tMax)
keep fips year avg_yearly_temp
duplicates drop
tempfile prism_1970_avgtemp
save `prism_1970_avgtemp'

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

* add state information
preserve
	import delimited "${path}Haru/data/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

* set seed
set seed 1642
********************************************************************************
** RUN
********************************************************************************
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

foreach source in prism_1970 { //era5_F schlenker_F ghcn_ext prism_1970
      global source = "`source'"

      local data_`source'_naive = "`data_`source'_year'"
      local data_`source'_adapt0 = "`data_`source'_year'"
      local data_`source'_adapt1 = "`data_`source'_year'"
      local data_`source'_trends = "`data_`source'_year'"
      local data_`source'_stateyearFE = "`data_`source'_year'"
      local data_`source'_lag3 = "`data_`source'_year'"
      local data_`source'_5year = "`data_`source'_year'"

      local row = "`row' \midrule \multirow{8}{*}{`title_`source''}"
      
      foreach method in naive stateyearFE lag3 trends 5year year chebyshev splines aggregate { // naive stateyearFE lag3 trends 5year year year_bayes avgtrend avgtrend_bayes chebyshev splines aggregate
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

            * adaptation
            if strpos("`method'", "adapt") > 0 {
                  
                  * divide sample into two: above and below pre temp median
                  sum baselinePeriodTemp, detail
                  local medianPreTemp = `r(p50)'

                  gen aboveMedian = baselinePeriodTemp > `medianPreTemp'
                  local num = substr("`method'", -1, 1) //extract digit the end
                  dis "`num'"
                  keep if aboveMedian == `num'
            }

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

            ******************************* Simulation 2 coefficient and SE, trend in Y
            local compare = cond(strpos("`method'", "naive") > 0 | strpos("`method'", "adapt") > 0, "none", cond(strpos("`method'", "trends") > 0, "trends, fips#c.year", cond(strpos("`method'", "stateyearFE") > 0, "stateyear, stateyear fips", cond(strpos("`method'", "lag") > 0, "lags, 3", cond(strpos("`method'", "5year") > 0, "5year, county5year year", "cftemp"))))) //different from sim 1 compare! cftemp instead of sim

            * Initialize
            foreach bin in under_`lb_str' over_`ub_str' {
                  local `source'_row_`bin' = "``source'_row_`bin'' & \multirow{2}{*}{`title_`method''}"
                  local second_row_`bin' = " &"
            }

            * Loop through powers
            foreach power in linear quadratic cubic {
                  cftemp_sim baselinePeriodTemp fips year, simulate(1000) option(2) outcome(`power', 1) `bins_`source'' compare(`compare') fe(fips year) cluster(fips) extreme

                  foreach bin in under_`lb_str' over_`ub_str' {

                        * Fill in from globals passed from cftemp_sim
                        local `source'_row_`bin' = "``source'_row_`bin'' & ${coef_1_`bin'}"
                        local second_row_`bin' = "`second_row_`bin'' & [${p25_1_`bin'}, ${p975_1_`bin'}]"
                  }
            }

            * Conjoin first and second rows
            foreach bin in under_`lb_str' over_`ub_str' {
                  local `source'_row_`bin' = "``source'_row_`bin'' \\ `second_row_`bin'' \\"
            }

      }

      local `source'_row_under_`lb_str' = "\midrule \multirow{50}{*}{`title_`source''} & \textit{Under 10 Bin} \\ ``source'_row_under_`lb_str''"

      dis "``source'_row_under_`lb_str''"
      dis "``source'_row_over_`ub_str''"

      file open power_`source' using "${output}/bindev/power_table_`source'.tex", write replace
      file write power_`source' ///
            "\clearpage" _n ///
            "\thispagestyle{empty}" _n ///
            "\begin{table}[htb]" _n ///
            "\centering" _n ///
            "\caption{Comparison of \texttt{cftemp} Methods Under Higher Order Trends (`title_`source'')}" _n ///
            "\label{cftemp-comp}" _n ///
            "\begin{threeparttable}" _n ///
            "\scalebox{0.75}{" _n ///
            "\begin{tabular}{llccc}" _n ///
            "\toprule" _n ///
            "Dataset & \multicolumn{1}{c}{Method} & Linear & Quadratic & Cubic \\" _n ///
            "\midrule" _n ///
            "``source'_row_under_`lb_str''" _n ///
            "\cmidrule(lr){2-5}  & \textit{Over 90 Bin} \\" _n ///
            "``source'_row_over_`ub_str''" _n ///
            "\hline \hline" _n ///
            "\end{tabular}" _n ///
            "}" _n ///
            "\begin{tablenotes}" _n ///
            "\footnotesize \textit{Notes:} All temperatures are in \degree F. `sample_`source''" _n ///
            "\end{tablenotes}" _n ///
            "\end{threeparttable}" _n ///
            "\end{table}" _n
      file close power_`source'
}
