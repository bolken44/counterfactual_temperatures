/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: July 2025
ACTION: Creates density plots of the simulation coefficients and t-stats
*******************************************************************************
Run setup file
*********************************/
args data repkit
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"

log using "${log}5_density_plots/5_density_plots.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Locals
*********************************/
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

/*********************************
Run
*********************************/
foreach source in era5 prism_1950 prism_1970 ghcn {

      foreach power in linear quadratic cubic {

            *** Import the appended csv
            import delimited "${intermediate}power_table_`power'_`source'.csv", clear

            foreach bin in under_10 over_90 {

                  preserve
                  
                  keep if varname == "real_`bin'"

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
                  graph export "${density}coef_plot_naive_`power'_`bin'_`source'.pdf", replace

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
                  graph export "${density}coef_plot_cftemp_`power'_`bin'_`source'.pdf", replace

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
                  graph export "${density}tstat_plot_naive_`power'_`bin'_`source'.pdf", replace

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
                  graph export "${density}tstat_plot_cftemp_`power'_`bin'_`source'.pdf", replace

                  * Legend
                  dis "\caption*{\color{p1line}{\textemdash\textemdash} `title_naive' (Under 10 Bin: `sig_naive_under_10'\%, Over 90 Bin: `sig_naive_over_90'\%) \hspace{1cm} \color{p2line}{- - -} `title_stateyearFE' (`sig_stateyearFE_under_10'\%, `sig_stateyearFE_over_90'\%) \hspace{3cm} \color{p3line}{- - -} `title_lag3' (`sig_lag3_under_10'\%, `sig_lag3_over_90'\%) \hspace{1cm}} \caption*{\color{p4line}{- - -} `title_trends' (`sig_trends_under_10'\%, `sig_trends_over_90'\%) \hspace{1cm} \color{p5line}{- - -} `title_5year' (`sig_5year_under_10'\%, `sig_5year_over_90'\%)}"

                  dis "\caption*{\color{p1line}{\textemdash\textemdash} `title_naive' (Under 10 Bin: `sig_naive_under_10'\%, Over 90 Bin: `sig_naive_over_90'\%) \hspace{1cm} \color{p2line}{- - -} `title_year' (`sig_year_under_10'\%, `sig_year_over_90'\%) \hspace{1cm} \color{p3line}{- - -} `title_year_bayes' (`sig_year_bayes_under_10'\%, `sig_year_bayes_over_90'\%) \hspace{1cm}} \caption*{\color{p4line}{- - -} `title_avgtrend' (`sig_avgtrend_under_10'\%, `sig_avgtrend_over_90'\%) \hspace{1cm} \color{p5line}{- - -} `title_avgtrend_bayes' (`sig_avgtrend_bayes_under_10'\%, `sig_avgtrend_bayes_over_90'\%) \hspace{1cm} \color{p6line}{- - -} `title_chebyshev' (`sig_chebyshev_under_10'\%, `sig_chebyshev_over_90'\%)}"

                  restore 
            }
      }
}