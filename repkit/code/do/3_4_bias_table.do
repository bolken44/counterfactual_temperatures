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
global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/"

log using "${log}3_1_simulations/3_4_bias_table_`task'.txt", text replace
display "Current time: " c(current_date) " " c(current_time)


/*********************************
Run
*********************************/
foreach binform in allbins extreme {
      foreach source in era5 { // prism_1950 prism_1970 ghcn 

            *** Import the appended csv
            import delimited "${intermediate}power_table_`power'_`binform'_`source'.csv", clear

            foreach bin in under_$lb_str over_$ub_str {

                  preserve
                  keep if varname == "real_`bin'"

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
            foreach bin in under_$lb_str over_$ub_str {
                  
                  * Initialize
                  local `source'_row_`bin' = "``source'_row_`bin'' & \multirow{2}{*}{`title_`method''}"
                  local second_row = " &"

                  * Fill in
                  local `source'_row_`bin' = "``source'_row_`bin'' & `sim2_coef_`bin'' & `sim2_tstat_`bin'' & ${slope_`bin'_str} & ${resid_`bin'_str} & ${coef_1_Y_str} & ${bias2_`bin'}"
                  local second_row = "`second_row' & `sim2_ci_`bin'' & `sim2_tstat_ci_`bin'' & ${trend_ci_`bin'} & ${coef_1_Y_ci} &"
                  
                  * Conjoin first and second rows
                  local `source'_row_`bin' = "``source'_row_`bin'' \\ `second_row' \\"
            }

            local `source'_row_under_$lb_str = "\midrule \multirow{50}{*}{\shortstack{`title_`source'' \\ \(\sigma^2_{T_0} = ${sigma2_T0_str}\)}} & \textit{Under 10 Bin} \\ ``source'_row_under_$lb_str'"

            * Export as Latex File
            dis "``source'_row_under_$lb_str'"
            dis "``source'_row_over_$ub_str'"

            file open cftemp_`task'_$lb_str using "${temp}cftemp_comp_`source'_`task'_under_$lb_str.tex", write replace
            file write cftemp_`task'_$lb_str ///
                  "``source'_row_under_$lb_str'" _n
            file close cftemp_`task'_$lb_str

            file open cftemp_`task'_$ub_str using "${temp}cftemp_comp_`source'_`task'_over_$ub_str.tex", write replace
            file write cftemp_`task'_$ub_str ///
                  "``source'_row_over_$ub_str'" _n
            file close cftemp_`task'_$ub_str
      }
}