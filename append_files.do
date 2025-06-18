/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: June 2025 - Appends files created by parallel_bias_table.do
ACTION: Creates tables to compare binning bias across different cftemp versions.
*******************************************************************************/

clear all
set more off

global path "/proj/pbolken/climate/"
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

log using "${path}Haru/log/append_files.txt", text replace
display "Current time: " c(current_date) " " c(current_time)
*******************************************************************************/

local k = 1
foreach source in era5_F schlenker_F ghcn_ext { //era5_F schlenker_F ghcn_ext prism_1970

      // Define output file name
      local output_tex "${output}/bindev/cftemp_comp_`source'.tex"
      local output_csv "${output}/bindev/cftemp_comp_`source'.tex"

      // Delete the output file if it already exists to avoid appending multiple times
      shell rm -f `output_tex'

      // Append files _1.tex to _12.tex into the output file
      forvalues i = 1/12 {
            local j = 12 * (`k' - 1) + `i'
            
            *** TEXs
            foreach bin in under_10 over_90 {
                  file open in using "cftemp_comp_`source'_`j'_`bin'.tex", read
                  
                  while (r(eof)==0) {
                        file read in line
                        if (r(eof)==0) {
                              local `source'_row_`bin'  "``source'_row_`bin'' `line'"
                        }
                  }

                  file close in

            }
            
            
            *** CSVs
            shell rm -f `output_csv'

            if `i' == 1 {
                  // Include header for the first file
                  shell cat "${output}/bindev/cftemp_`source'_linear_`j'.csv" >> `output_csv'
            }
            else {
                  // Skip header (first line) for all subsequent files
                  shell tail -n +2 "${output}/bindev/cftemp_`source'_linear_`j'.csv" >> `output_csv'
            }
      }

      *** Write the output tex
      file open cftemp_`source' using "`output_tex'", write replace
      file write cftemp_`source' ///
            "\clearpage" _n ///
            "\thispagestyle{empty}" _n ///
            "\newgeometry{top=1in, bottom=1in, left=0.3in, right=0.3in}" _n ///
            "\begin{landscape}" _n ///
            "\begin{table}[htb]" _n ///
            "\centering" _n ///
            "\caption{Comparison of Different \texttt{cftemp} Methods (`title_`source'')}" _n ///
            "\label{cftemp-comp}" _n ///
            "\begin{threeparttable}" _n ///
            "\scalebox{0.75}{" _n ///
            "\begin{tabular}{llcccccc}" _n ///
            "\toprule" _n ///
            "Dataset & \multicolumn{1}{c}{Method} & Coef & t-Stat & \(\omega_{C \text{ or } H}\) & \(\sigma^2_{e_{C \text{ or } H}}\) & \(\omega_Y\) & Bias \\" _n ///
            "\midrule" _n ///
            "``source'_row_under_`lb_str''" _n ///
            "\cmidrule(lr){2-8}  & \textit{Over 90 Bin} \\" _n ///
            "``source'_row_over_`ub_str''" _n ///
            "\hline \hline" _n ///
            "\end{tabular}" _n ///
            "}" _n ///
            "\begin{tablenotes}" _n ///
            "\footnotesize \textit{Notes:} All temperatures are in \degree F. The sample period is 1970-2019 for ERA Land 5, 1970-2019 for PRISM, and 1970-2016 for GHCN." _n ///
            "\end{tablenotes}" _n ///
            "\end{threeparttable}" _n ///
            "\end{table}" _n ///
            "\end{landscape}" _n ///
            "\restoregeometry" _n
      file close cftemp_`source'

      local k = `k' + 1
}

*** Import the appended csv
import delimited "`output_csv'", clear

* Plot distribution of `coef`
// Define local macros for labels
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
local title_aggregate = "Aggregate ±5 Years"

// First plot - Distribution of Coefficients
twoway ///
    (kdensity coef if method == "naive", lcolor(black)) ///
    (kdensity coef if method == "stateyearFE", lcolor(red)) ///
    (kdensity coef if method == "lag3", lcolor(green)) ///
    (kdensity coef if method == "trends", lcolor(blue)) ///
    (kdensity coef if method == "5year", lcolor(purple)) ///
    , title("Distribution of Sim 2 Coefficients") ///
      legend(position(6) ring(0) cols(1) ///
             order(1 2 3 4 5) ///
             label(1 "`title_naive'") ///
             label(2 "`title_stateyearFE'") ///
             label(3 "`title_lag3'") ///
             label(4 "`title_trends'") ///
             label(5 "`title_5year'"))
graph export "${output}/bindev/coef_plot_naive.pdf", replace

twoway ///
    (kdensity coef if method == "year", lcolor(black)) ///
    (kdensity coef if method == "year_bayes", lcolor(red)) ///
    (kdensity coef if method == "lag3", lcolor(green)) ///
    (kdensity coef if method == "avgtrend", lcolor(blue)) ///
    (kdensity coef if method == "avgtrend_bayes", lcolor(purple)) ///
    (kdensity coef if method == "chebyshev", lcolor(orange)) ///
    , title("Distribution of Sim 2 Coefficients") ///
      legend(position(6) ring(0) cols(1) ///
             order(1 2 3 4 5 6) ///
             label(1 "`title_year'") ///
             label(2 "`title_year_bayes'") ///
             label(3 "`title_lag3'") ///
             label(4 "`title_avgtrend'") ///
             label(5 "`title_avgtrend_bayes'") ///
             label(6 "`title_chebyshev'"))
graph export "${output}/bindev/coef_plot_cftemp.pdf", replace

* Plot distribution of `tstat`
twoway ///
    (kdensity tstat if method == "naive", lcolor(black)) ///
    (kdensity tstat if method == "stateyearFE", lcolor(red)) ///
    (kdensity tstat if method == "lag3", lcolor(green)) ///
    (kdensity tstat if method == "trends", lcolor(blue)) ///
    (kdensity tstat if method == "5year", lcolor(purple)) ///
    , title("Distribution of Sim 2 t-Stats") ///
      legend(position(6) ring(0) cols(1) ///
             order(1 2 3 4 5) ///
             label(1 "`title_naive'") ///
             label(2 "`title_stateyearFE'") ///
             label(3 "`title_lag3'") ///
             label(4 "`title_trends'") ///
             label(5 "`title_5year'"))
graph export "${output}/bindev/tstat_plot_naive.pdf", replace

twoway ///
    (kdensity tstat if method == "year", lcolor(black)) ///
    (kdensity tstat if method == "year_bayes", lcolor(red)) ///
    (kdensity tstat if method == "lag3", lcolor(green)) ///
    (kdensity tstat if method == "avgtrend", lcolor(blue)) ///
    (kdensity tstat if method == "avgtrend_bayes", lcolor(purple)) ///
    (kdensity tstat if method == "chebyshev", lcolor(orange)) ///
    , title("Distribution of Sim 2 t-Stats") ///
      legend(position(6) ring(0) cols(1) ///
             order(1 2 3 4 5 6) ///
             label(1 "`title_year'") ///
             label(2 "`title_year_bayes'") ///
             label(3 "`title_lag3'") ///
             label(4 "`title_avgtrend'") ///
             label(5 "`title_avgtrend_bayes'") ///
             label(6 "`title_chebyshev'"))
graph export "${output}/bindev/tstat_plot_cftemp.pdf", replace