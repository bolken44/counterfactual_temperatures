/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: June 2025
ACTION: 
      Appends files created by parallel_bias_table.do
      Plots the density of sim 2 coefficients and t-stats
*******************************************************************************/

global home "/orcd/home/002/hnaka24/climate/"
global output "${home}output/"

global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/"

log using "${home}log/append_files.txt", text replace
display "Current time: " c(current_date) " " c(current_time)
set linesize 255

ssc install schemepack, replace
set scheme white_tableau

*******************************************************************************/
*** Append Files
*******************************************
local k = 1

local title_era5_F = "ERA 5"
local title_schlenker_F = "PRISM"
local title_prism_1970 = "PRISM (1970-2019)"
local title_ghcn_ext = "GHCN"

local sample_era5_F = "The sample period is 1970-2019 for ERA Land 5."
local sample_schlenker_F = "The sample period is 1950-2019 for this version of PRISM."
local sample_prism_1970 = "The sample period is 1970-2019 for this version of PRISM."
local sample_ghcn_ext = "The sample period is 1970-2016 for GHCN."

local table = "power_table" // "cftemp_comp"
local power = "quadratic" // "cubic" "quadratic" "linear" // relevant for csvs and figures only

foreach source in era5_F { //era5_F schlenker_F ghcn_ext prism_1970

      // Define output file name
      local output_tex "${output}bindev/`table'_`source'.tex"
      local output_csv "${output}bindev/`table'_`power'_`source'.csv"

      // Delete the output file if it already exists to avoid appending multiple times
      shell rm -f `output_tex'
      shell rm -f `output_csv'

      // Append files _1.tex to _12.tex into the output file
      forvalues i = 1/12 {
            local j = 12 * (`k' - 1) + `i'
            
            *** TEXs
            foreach bin in under_10 over_90 {
                  local `source'_row_`bin' = ""

                  file open in using "${output}bindev/`table'_`source'_`j'_`bin'.tex", read text
                  file read in line
                  
                  while (r(eof)==0) {
                        local `source'_row_`bin'  "``source'_row_`bin'' `line'"
                        file read in line
                  }

                  file close in

            }
            
            
            *** CSVs
            if `i' == 1 {
                  // Include header for the first file
                  shell cat "${output}bindev/cftemp_`source'_`power'_`j'.csv" >> `output_csv'
            }
            else {
                  // Skip header (first line) for all subsequent files
                  shell tail -n +2 "${output}bindev/cftemp_`source'_`power'_`j'.csv" >> `output_csv'
            }
            /* shell rm -f "${output}/bindev/cftemp_`source'_`power'_`j'.csv" */
      }

      *** Write the output tex
      file open cftemp_`source' using "`output_tex'", write replace
      if "`table'" == "cftemp_comp" {
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
                  "``source'_row_under_10'" _n ///
                  "\cmidrule(lr){2-8}  & \textit{Over 90 Bin} \\" _n ///
                  "``source'_row_over_90'" _n ///
                  "\hline \hline" _n ///
                  "\end{tabular}" _n ///
                  "}" _n ///
                  "\begin{tablenotes}" _n ///
                  "\footnotesize \textit{Notes:} All temperatures are in \degree F. `sample_`source''" _n ///
                  "\end{tablenotes}" _n ///
                  "\end{threeparttable}" _n ///
                  "\end{table}" _n ///
                  "\end{landscape}" _n ///
                  "\restoregeometry" _n
            file close cftemp_`source'
      }
      else if "`table'" == "power_table" {
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
                  "\scalebox{0.70}{" _n ///
                  "\begin{tabular}{llcccccc}" _n ///
                  "\toprule" _n ///
                  "\multirow{2}{*}{Dataset} & \multirow{2}{*}{Method} & \multicolumn{2}{c}{Linear} & \multicolumn{2}{c}{Quadratic} & \multicolumn{2}{c}{Cubic} \\" _n ///
                  " & & Coef & t-Stat & Coef & t-Stat & Coef & t-Stat \\" _n ///
                  "\midrule" _n ///
                  "``source'_row_under_10'" _n ///
                  "\cmidrule(lr){2-8}  & \textit{Over 90 Bin} \\" _n ///
                  "``source'_row_over_90'" _n ///
                  "\hline \hline" _n ///
                  "\end{tabular}" _n ///
                  "}" _n ///
                  "\begin{tablenotes}" _n ///
                  "\footnotesize \textit{Notes:} All temperatures are in \degree F. `sample_`source''" _n ///
                  "\end{tablenotes}" _n ///
                  "\end{threeparttable}" _n ///
                  "\end{table}" _n ///
                  "\end{landscape}" _n ///
                  "\restoregeometry" _n
            file close cftemp_`source'
      }

      local k = `k' + 1


*******************************************************************************/
*** Plot density
*******************************************
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

      foreach bin in under_10 over_90 {

            preserve
            
            keep if varname == "real_`bin'"
            /* replace bias = log(bias) */

            foreach method in naive stateyearFE lag3 trends 5year year year_bayes avgtrend avgtrend_bayes chebyshev splines aggregate { //
                  count if pvalue <= 0.05 & method == "`method'"
                  local sig_`method'_`bin' = string(round(r(N) /10, 0.1), "%4.1f")
            }

            * Plot distribution of coefficients
            twoway ///
            (kdensity coef if method == "naive", lpattern(solid) color("31 88 137") lwidth(thick)) ///
            (kdensity coef if method == "stateyearFE", lpattern(dash) color("155 52 58") lwidth(thick)) ///
            (kdensity coef if method == "lag3", lpattern(dash) color("44 160 44") lwidth(thick)) ///
            (kdensity coef if method == "trends", lpattern(dash) color("255 127 14") lwidth(thick)) ///
            (kdensity coef if method == "5year", lpattern(dash) color("148 103 189") lwidth(thick)) ///
            , ///
            graphregion(color(white)) ///
            xline(0, lcolor(gs10) lpattern(dash)) ///
            xlabel(, nogrid) ///
            ylabel(, nogrid) ///
            xtitle("Coefficient", size(small)) ///
            ytitle("Density", size(small)) legend(off)
            /* legend(position(6) cols(2) size(vsmall) ///
                  order(1 2 3 4 5) ///
                  label(1 "`title_naive' (`sig_naive'%)") ///
                  label(2 "`title_stateyearFE' (`sig_stateyearFE'%)") ///
                  label(3 "`title_lag3' (`sig_lag3'%)") ///
                  label(4 "`title_trends' (`sig_trends'%)") ///
                  label(5 "`title_5year' (`sig_5year'%)")) /// */
            graph export "${output}bindev/coef_plot_naive_`power'_`bin'_`source'.pdf", replace

            twoway ///
            (kdensity coef if method == "naive", lpattern(solid) color("31 88 137") lwidth(thick)) ///
            (kdensity coef if method == "year", lpattern(dash) color("44 160 44") lwidth(thick)) ///
            (kdensity coef if method == "year_bayes", lpattern(dash) color("155 52 58") lwidth(thick)) ///
            (kdensity coef if method == "chebyshev", lpattern(dash) color("255 127 14") lwidth(thick)) ///
            , ///
            graphregion(color(white)) ///
            xline(0, lcolor(gs10) lpattern(dash)) ///
            xtitle("Coefficient", size(small)) ///
            ytitle("Density", size(small)) legend(off) ///
            xlabel(, nogrid) ///
            ylabel(, nogrid) ///
            /* legend(position(6) cols(2) size(vsmall) ///
                  order(1 2 3 4 5 6) ///
                  label(1 "`title_naive' (`sig_naive'%)") ///
                  label(2 "`title_year' (`sig_year'%)") ///
                  label(3 "`title_year_bayes' (`sig_year_bayes'%)") ///
                  label(4 "`title_avgtrend' (`sig_avgtrend'%)") ///
                  label(5 "`title_avgtrend_bayes' (`sig_avgtrend_bayes'%)") ///
                  label(6 "`title_chebyshev' (`sig_chebyshev'%)")) /// */
            /* (kdensity coef if method == "avgtrend", lpattern(dash) lwidth(thick)) ///
            (kdensity coef if method == "avgtrend_bayes", lpattern(dash) lwidth(thick)) /// */
            graph export "${output}bindev/coef_plot_cftemp_`power'_`bin'_`source'.pdf", replace

            * Plot distribution of tstat
            twoway ///
            (kdensity tstat if method == "naive", lpattern(solid) color("31 88 137") lwidth(thick)) ///
            (kdensity tstat if method == "stateyearFE", lpattern(dash) color("155 52 58") lwidth(thick)) ///
            (kdensity tstat if method == "lag3", lpattern(dash) color("44 160 44") lwidth(thick)) ///
            (kdensity tstat if method == "trends", lpattern(dash) color("255 127 14") lwidth(thick)) ///
            (kdensity tstat if method == "5year", lpattern(dash) color("148 103 189") lwidth(thick)) ///
            , ///
            graphregion(color(white)) ///
            xline(0, lcolor(gs10) lpattern(dash)) ///
            xline(1.96, lcolor(gs10) lpattern(dash)) ///
            xline(-1.96, lcolor(gs10) lpattern(dash)) ///
            xlabel(-5(5)10 1.96 "1.96" -1.96 "-1.96", nogrid) ///
            ylabel(, nogrid) ///
            xtitle("t-Stats", size(small)) ///
            ytitle("Density", size(small)) legend(off)
            /* legend(position(6) cols(2) size(vsmall) ///
                  order(1 2 3 4 5) ///
                  label(1 "`title_naive'") ///
                  label(2 "`title_stateyearFE'") ///
                  label(3 "`title_lag3'") ///
                  label(4 "`title_trends'") ///
                  label(5 "`title_5year'")) /// */
            graph export "${output}bindev/tstat_plot_naive_`power'_`bin'_`source'.pdf", replace

            twoway ///
            (kdensity tstat if method == "naive", lpattern(solid) color("31 88 137") lwidth(thick)) ///
            (kdensity tstat if method == "year", lpattern(dash) color("44 160 44") lwidth(thick)) ///
            (kdensity tstat if method == "year_bayes", lpattern(dash) color("155 52 58") lwidth(thick)) ///
            (kdensity tstat if method == "chebyshev", lpattern(dash) color("255 127 14") lwidth(thick)) ///
            , ///
            graphregion(color(white)) ///
            xline(0, lcolor(gs10) lpattern(dash)) ///
            xline(1.96, lcolor(gs10) lpattern(dash)) ///
            xline(-1.96, lcolor(gs10) lpattern(dash)) ///
            xlabel(-5(5)10 1.96 "1.96" -1.96 "-1.96", nogrid) ///
            ylabel(, nogrid) ///
            xtitle("t-Stats", size(small)) ///
            ytitle("Density", size(small)) legend(off)
            /* legend(position(6) cols(2) size(vsmall) ///
                  order(1 2 3 4 5 6) ///
                  label(1 "`title_naive'") ///
                  label(2 "`title_year'") ///
                  label(3 "`title_year_bayes'") ///
                  label(4 "`title_avgtrend'") ///
                  label(5 "`title_avgtrend_bayes'") ///
                  label(6 "`title_chebyshev'")) /// */
            /* (kdensity tstat if method == "avgtrend", lpattern(dash) lwidth(thick)) ///
            (kdensity tstat if method == "avgtrend_bayes", lpattern(dash) lwidth(thick)) /// */
            graph export "${output}bindev/tstat_plot_cftemp_`power'_`bin'_`source'.pdf", replace

            * Legend
            dis "\caption*{\color{p1line}{\textemdash\textemdash} `title_naive' (Under 10 Bin: `sig_naive_under_10'\%, Over 90 Bin: `sig_naive_over_90'\%) \hspace{1cm} \color{p2line}{- - -} `title_stateyearFE' (`sig_stateyearFE_under_10'\%, `sig_stateyearFE_over_90'\%) \hspace{3cm} \color{p3line}{- - -} `title_lag3' (`sig_lag3_under_10'\%, `sig_lag3_over_90'\%) \hspace{1cm}} \caption*{\color{p4line}{- - -} `title_trends' (`sig_trends_under_10'\%, `sig_trends_over_90'\%) \hspace{1cm} \color{p5line}{- - -} `title_5year' (`sig_5year_under_10'\%, `sig_5year_over_90'\%)}"

            dis "\caption*{\color{p1line}{\textemdash\textemdash} `title_naive' (Under 10 Bin: `sig_naive_under_10'\%, Over 90 Bin: `sig_naive_over_90'\%) \hspace{1cm} \color{p2line}{- - -} `title_year' (`sig_year_under_10'\%, `sig_year_over_90'\%) \hspace{1cm} \color{p3line}{- - -} `title_year_bayes' (`sig_year_bayes_under_10'\%, `sig_year_bayes_over_90'\%) \hspace{1cm}} \caption*{\color{p4line}{- - -} `title_avgtrend' (`sig_avgtrend_under_10'\%, `sig_avgtrend_over_90'\%) \hspace{1cm} \color{p5line}{- - -} `title_avgtrend_bayes' (`sig_avgtrend_bayes_under_10'\%, `sig_avgtrend_bayes_over_90'\%) \hspace{1cm} \color{p6line}{- - -} `title_chebyshev' (`sig_chebyshev_under_10'\%, `sig_chebyshev_over_90'\%)}"

            * Plot distribution of bias
            /* twoway ///
            (kdensity bias if method == "naive", lcolor(black)) ///
            (kdensity bias if method == "stateyearFE", lcolor(red)) ///
            (kdensity bias if method == "lag3", lcolor(green)) ///
            (kdensity bias if method == "trends", lcolor(blue)) ///
            (kdensity bias if method == "5year", lcolor(purple)) ///
            , ///
                  graphregion(color(white)) ///
                  legend(position(6) cols(2) size(vsmall) ///
                        order(1 2 3 4 5) ///
                        label(1 "`title_naive'") ///
                        label(2 "`title_stateyearFE'") ///
                        label(3 "`title_lag3'") ///
                        label(4 "`title_trends'") ///
                        label(5 "`title_5year'")) ///
                  xline(0, lcolor(gs10) lpattern(dash)) ///
                  xtitle("Log Bias", size(small)) ///
                  ytitle("Density", size(small))
            graph export "${output}bindev/bias_plot_naive_`power'_`bin'_`source'.pdf", replace

            twoway ///
            (kdensity bias if method == "naive", lcolor(gray)) ///
            (kdensity bias if method == "year", lcolor(black)) ///
            (kdensity bias if method == "year_bayes", lcolor(red)) ///
            (kdensity bias if method == "avgtrend", lcolor(blue)) ///
            (kdensity bias if method == "avgtrend_bayes", lcolor(green)) ///
            (kdensity bias if method == "chebyshev", lcolor(orange)) ///
            , ///
                  graphregion(color(white)) ///
                  legend(position(6) cols(2) size(vsmall) ///
                        order(1 2 3 4 5 6) ///
                        label(1 "`title_naive'") ///
                        label(2 "`title_year'") ///
                        label(3 "`title_year_bayes'") ///
                        label(4 "`title_avgtrend'") ///
                        label(5 "`title_avgtrend_bayes'") ///
                        label(6 "`title_chebyshev'")) ///
                  xline(0, lcolor(gs10) lpattern(dash)) ///
                  xtitle("Log Bias", size(small)) ///
                  ytitle("Density", size(small))
            graph export "${output}bindev/bias_plot_cftemp_`power'_`bin'_`source'.pdf", replace */
            restore 
      }

}
//