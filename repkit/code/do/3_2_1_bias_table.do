/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: July 2025
ACTION: Creates the bias table
*******************************************************************************
Set Up
*********************************/
args data repkit task
global data "`data'"
global repkit "`repkit'"
global task `task'

do "${repkit}code/do/0_setup.do"

log using "${log}3_2_analysis/3_2_1_bias_table.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

* Simulated Methods
local methods_full  "naive stateyearFE lag3 trends 5year year bayes chebyshev adapt"
local n_methods  : word count `methods_full'

* Methods Used in the Bias Table
local methods  "naive stateyearFE lag3 trends 5year year bayes chebyshev"

/*********************************
Locals for bias table
*********************************/
local title_era5 = "ERA 5 (1970-2019)"
local title_prism_1950 = "PRISM (1950-2019)"
local title_prism_1970 = "PRISM (1970-2019)"
local title_ghcn = "GHCN (1970-2016)"

local sample_era5 = "The sample period is 1970-2019 for ERA Land 5."
local sample_prism_1950 = "The sample period is 1950-2019 for this version of PRISM."
local sample_prism_1970 = "The sample period is 1970-2019 for this version of PRISM."
local sample_ghcn = "The sample period is 1970-2016 for GHCN."

local title_naive = "No correction"
local title_stateyearFE = "State-Year Fixed Effects"
local title_lag3 = "With 3 Lags"
local title_trends = "County-Specific Linear Trends"
local title_5year = "County-5 Year Fixed Effects"
local title_year = "Counterfactual Temp. Control without Bayes "
local title_bayes = "Counterfactual Temp. Control"
local title_chebyshev = "Chebyshev"

/*********************************
Run Main Bias Table (Table A1)
*********************************/
local k = 1 // counts sources
foreach source in era5 { // prism_1950 prism_1970 ghcn 

      local i = 1 // counts methods

      foreach method in `methods' {

            *** Import the csv
            local j = `n_methods' * (`k') + `i'
            import delimited "${temp}cftemp_`source'_bin${binsize}_lin_extreme_`j'", clear case(preserve)
            keep if method == "`method'"

            * omega Y
            _pctile trend_Y, nq(1000)
            global coef_p25_1_Y  = string(round(`r(r25)', 0.00001))
            global coef_p975_1_Y = string(round(`r(r975)', 0.00001))

            global coef_1_Y_str = string(round(`r(r500)', 0.00001))
            global coef_1_Y_ci  = "[${coef_p25_1_Y}, ${coef_p975_1_Y}]"

            foreach bin in under_${lb_str} over_${ub_str} {

                  preserve
                  keep if varName == "real_`bin'"

                  * sim 2 coefficients and t-stats
                  _pctile coef, nq(1000)
                  local sim2_coef_`bin' = string(round(`r(r500)', 0.00001))
                  local sim2_p25_`bin' = string(round(`r(r25)', 0.00001))
                  local sim2_p975_`bin' = string(round(`r(r975)', 0.00001))
                  local sim2_ci_`bin' = "[`sim2_p25_`bin'', `sim2_p975_`bin'']"

                  _pctile tstat, nq(1000)
                  local sim2_tstat_`bin' = string(round(`r(r500)', 0.00001))
                  local sim2_p25_`bin' = string(round(`r(r25)', 0.00001))
                  local sim2_p975_`bin' = string(round(`r(r975)', 0.00001))
                  local sim2_tstat_ci_`bin' = "[`sim2_p25_`bin'', `sim2_p975_`bin'']"

                  * omega C and H
                  sum slope_`bin'
                  local slope_`bin' = r(mean)
                  global slope_`bin'_str : display %9.0g `slope_`bin''

                  sum se_`bin'
                  local se_`bin' = r(mean)

                  local lb_`bin'    = string(`slope_`bin'' - 1.96 * `se_`bin'', "%9.0g")
                  local ub_`bin'    = string(`slope_`bin'' + 1.96 * `se_`bin'', "%9.0g")
                  global trend_ci_`bin' = "[`lb_`bin'', `ub_`bin'']"

                  * residuals
                  sum resid_`bin'
                  global resid_`bin'_str = string(r(mean), "%9.0g")

                  * sigma T_0
                  sum sigma_T0
                  global sigma2_T0_str = string(round(r(mean)^2, 0.01))

                  * Bias
                  _pctile bias, nq(1000)
                  local bias2_`bin' = string(round(`r(r500)', 0.00001))
                  local bias2_p25_`bin' = string(round(`r(r25)', 0.00001))
                  local bias2_p975_`bin' = string(round(`r(r975)', 0.00001))
                  local bias2_ci_`bin' = "[`bias2_p25_`bin'', `bias2_p975_`bin'']"

                  restore
            }

            * Source column
            local `source'_header = "\midrule \multirow{34}{*}{\shortstack{`title_`source'' \\ \(\sigma^2_{T_0} = ${sigma2_T0_str}\)}} & \textit{Under 10 Bin} \\"

            * Finite T case
            foreach bin in under_${lb_str} over_${ub_str} {
                  
                  * Initialize
                  local `source'_row_`bin'_`task' = " & \multirow{2}{*}{`title_`method''}"
                  local second_row = " &"

                  * Fill in
                  local `source'_row_`bin'_`task' = "``source'_row_`bin'_`task'' & `sim2_coef_`bin'' & `sim2_tstat_`bin'' & ${slope_`bin'_str} & ${resid_`bin'_str} & ${coef_1_Y_str} & `bias2_`bin''"
                  local second_row = "`second_row' & `sim2_ci_`bin'' & `sim2_tstat_ci_`bin'' & ${trend_ci_`bin'} & & ${coef_1_Y_ci} & `bias2_ci_`bin''"
                  
                  * Conjoin first and second rows
                  local `source'_row_`bin'_`task' = "``source'_row_`bin'_`task'' \\ `second_row' \\"

                  * Concatenate with other methods
                  if `i' == 1 & strpos("`bin'", "under") > 0 {
                        local `source'_row_under_${lb_str} = "``source'_header' ``source'_row_under_${lb_str}_`task''"
                  }
                  else {
                        local `source'_row_`bin' = "``source'_row_`bin'' ``source'_row_`bin'_`task''"
                  }
            }

            * Count methods
            local i = `i' + 1
      }

      *** Write the output tex
      * Bias Table
      file open bias_table_`source' using "${tables}bias_table_`source'_bin${binsize}_full.tex", write replace
      file write bias_table_`source' ///
            "\clearpage" _n ///
            "\thispagestyle{empty}" _n ///
            "\newgeometry{top=1in, bottom=1in, left=0.3in, right=0.3in}" _n ///
            "\begin{landscape}" _n ///
            "\begin{table}[htb]" _n ///
            "\centering" _n ///
            "\caption{Comparison of Different \texttt{cftemp} Methods (`title_`source'')}" _n ///
            "\label{cftemp-comp}" _n ///
            "\scalebox{0.75}{" _n ///
            "\begin{threeparttable}" _n ///
            "\begin{tabular}{llcccccc}" _n ///
            "\toprule" _n ///
            "Dataset & \multicolumn{1}{c}{Method} & Coef & t-Stat & \(\omega_{C \text{ or } H}\) & \(\sigma^2_{e_{C \text{ or } H}}\) & \(\omega_Y\) & Bias \\" _n ///
            "\midrule" _n ///
            "``source'_row_under_${lb_str}'" _n ///
            "\cmidrule(lr){2-8}  & \textit{Over 90 Bin} \\" _n ///
            "``source'_row_over_${ub_str}'" _n ///
            "\hline \hline" _n ///
            "\end{tabular}" _n ///
            "\begin{tablenotes}" _n ///
            "\textit{Notes:} All temperatures are in \degree F. `sample_`source'' All columns report statistics related to our main simulation exercise. Panel A reports statistic related to the under-10 degree bin and Panel B reports statistics related to the over-90 degree bin. All terms are as defined in Section \ref{sec:theory} and the bias formula is presented in equations \eqref{bias_C_ex} and \eqref{bias_H_ex}." _n ///
            "\end{tablenotes}" _n ///
            "\end{threeparttable}" _n ///
            "}" _n ///
            "\end{table}" _n ///
            "\end{landscape}" _n ///
            "\restoregeometry" _n
      file close bias_table_`source'

      * Count sources
      local k = `k' + 1
}


/*********************************
Run Adaptation Bias Table (Table A2)
*********************************/
local title_1 "Cold Counties"
local title_2 "Hot Counties"

local k = 1 // counts sources
foreach source in era5 { // prism_1950 prism_1970 ghcn 

      forval i = 1/2 { // 1 = cold counties, 2 = hot counties

            *** Import the csv
            import delimited "${temp}cftemp_`source'_bin${binsize}_lin_extreme_18_het`i'", clear case(preserve)

            * omega Y
            _pctile trend_Y, nq(1000)
            global coef_p25_1_Y  = string(round(`r(r25)', 0.00001))
            global coef_p975_1_Y = string(round(`r(r975)', 0.00001))

            global coef_1_Y_str = string(round(`r(r500)', 0.00001))
            global coef_1_Y_ci  = "[${coef_p25_1_Y}, ${coef_p975_1_Y}]"

            foreach bin in under_${lb_str} over_${ub_str} {

                  preserve
                  keep if varName == "real_`bin'"

                  * sim 2 coefficients and t-stats
                  _pctile coef, nq(1000)
                  local sim2_coef_`bin' = string(round(`r(r500)', 0.00001))
                  local sim2_p25_`bin' = string(round(`r(r25)', 0.00001))
                  local sim2_p975_`bin' = string(round(`r(r975)', 0.00001))
                  local sim2_ci_`bin' = "[`sim2_p25_`bin'', `sim2_p975_`bin'']"

                  _pctile tstat, nq(1000)
                  local sim2_tstat_`bin' = string(round(`r(r500)', 0.00001))
                  local sim2_p25_`bin' = string(round(`r(r25)', 0.00001))
                  local sim2_p975_`bin' = string(round(`r(r975)', 0.00001))
                  local sim2_tstat_ci_`bin' = "[`sim2_p25_`bin'', `sim2_p975_`bin'']"

                  * omega C and H
                  sum slope_`bin'
                  local slope_`bin' = r(mean)
                  global slope_`bin'_str : display %9.0g `slope_`bin''

                  sum se_`bin'
                  local se_`bin' = r(mean)

                  local lb_`bin'    = string(`slope_`bin'' - 1.96 * `se_`bin'', "%9.0g")
                  local ub_`bin'    = string(`slope_`bin'' + 1.96 * `se_`bin'', "%9.0g")
                  global trend_ci_`bin' = "[`lb_`bin'', `ub_`bin'']"

                  * residuals
                  sum resid_`bin'
                  global resid_`bin'_str = string(r(mean), "%9.0g")

                  * sigma T_0
                  sum sigma_T0
                  global sigma2_T0_`i' = string(round(r(mean)^2, 0.01))

                  * Bias
                  _pctile bias, nq(1000)
                  local bias2_`bin' = string(round(`r(r500)', 0.00001))
                  local bias2_p25_`bin' = string(round(`r(r25)', 0.00001))
                  local bias2_p975_`bin' = string(round(`r(r975)', 0.00001))
                  local bias2_ci_`bin' = "[`bias2_p25_`bin'', `bias2_p975_`bin'']"

                  restore
            }

            * Finite T case
            foreach bin in under_${lb_str} over_${ub_str} {
                  
                  * Initialize
                  local `source'_row_`bin'_het`i' = "``source'_row_`bin'_het`i'' & \multirow{2}{*}{`title_`i''}"
                  local second_row = " &"

                  * Fill in
                  local `source'_row_`bin'_het`i' = "``source'_row_`bin'_het`i'' & `sim2_coef_`bin'' & `sim2_tstat_`bin'' & ${slope_`bin'_str} & ${resid_`bin'_str} & ${coef_1_Y_str} & `bias2_`bin''"
                  local second_row = "`second_row' & `sim2_ci_`bin'' & `sim2_tstat_ci_`bin'' & ${trend_ci_`bin'} & & ${coef_1_Y_ci} & `bias2_ci_`bin''"
                  
                  * Conjoin first and second rows
                  local `source'_row_`bin'_het`i' = "``source'_row_`bin'_het`i'' \\ `second_row' \\"
            }
      }

      * Concatenate locals for this source
      local `source'_row = "\midrule \multirow{10}{*}{\shortstack{`title_`source'' \\ \(\sigma^2_{{T_0}_C} = ${sigma2_T0_1}\) \\ \(\sigma^2_{{T_0}_H} = ${sigma2_T0_2}\)}} & \textit{Under 10 Bin} \\ ``source'_row_under_${lb_str}_het1' ``source'_row_under_${lb_str}_het2' \cmidrule(lr){2-8} & \textit{Over 90 Bin} \\ ``source'_row_over_${ub_str}_het1' ``source'_row_over_${ub_str}_het2'"

      * Export as Latex File
      file open `source'_cftemp_adapt using "${tables}bias_table_`source'_bin${binsize}_adapt.tex", write replace
      file write `source'_cftemp_adapt ///
            "\clearpage" _n ///
            "\thispagestyle{empty}" _n ///
            "\newgeometry{top=0.3in, bottom=0.3in, left=0.3in, right=0.3in}" _n ///
            "\begin{landscape}" _n ///
            "\begin{table}[htb]" _n ///
            "\centering" _n ///
            "\caption{Adaptation Specification with Bias Formula}" _n ///
            "\label{tab:cftemp-comp-adaptation}" _n ///
            "\scalebox{0.75}{" _n ///
            "\begin{threeparttable}" _n ///
            "\begin{tabular}{llcccccc}" _n ///
            "\toprule" _n ///
            "Dataset & \multicolumn{1}{c}{County} & Coef & t-Stat & \(\omega_{C/H}\) & \(\sigma^2_{e_{C/H}}\) & \(\omega_Y\) & Bias \\" _n ///
"            \midrule" _n ///
            "``source'_row'" _n ///
            "\hline \hline" _n ///
            "\end{tabular}" _n ///
            "\begin{tablenotes}" _n ///
            "\textit{Notes:} All temperatures are in \degree F. `sample_`source'' The first column reports the coefficient from running 1,000 simulations as described in Section \ref{sec:sim2} with three bins -- hot, medium, and low -- separately for cold and hot counties." _n ///
            "\end{tablenotes}" _n ///
            "\end{threeparttable}" _n ///
            "}" _n ///
            "\end{table}" _n ///
            "\end{landscape}" _n ///
            "\restoregeometry" _n
      file close `source'_cftemp_adapt

      * Count sources
      local k = `k' + 1
}

log close

