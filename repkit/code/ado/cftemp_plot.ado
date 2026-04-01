/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Plots up to three regression results together in binned models of temperature

Requirements
- Dataset should be created with the cftemp package, so that variables for the realized number of days in each temperature bin
are named real_* and expected number of days are named exp_*.

*******************************************************************************/
cap prog drop cftemp_plot
program define cftemp_plot

      ******************************* Syntax
      syntax varlist(min=1 max=1) [, binsize(real 5) lb(real -10) ub(real 35) omit(real 4) aweights(varlist) fe(string) cluster(varlist) control(string) compare1(string) compare2(string) method(string) graph(string) if(string)]

      local yvar  : word 1 of `varlist'
      
      * Initialize all latent locals only defined under if conditions
      local regression ""
      local weight ""
      local condition ""
      local compare_type ""
      local compare_vars ""
      local compare2_type ""
      local compare2_vars ""
      local version_list ""
      local fe_naive ""
      local fe_cftemp ""
      local fe_trends ""
      local title0 ""
      local title1 ""
      local title2 ""
      local condition0 ""
      local condition1 ""
      local condition2 ""
      local legendhet ""
      local version_num = .
      local lags = ""
      local lags_2 = ""
      
      * Method option
      if "`method'" == "" | "`method'" == "ols" {
            local regression = "reghdfe"
      }
      if "`method'" == "ppml" {
            local regression = "ppmlhdfe"
      }
      
      * Weight option
      if "`aweights'" != "" {
        local weight "[aw = `aweights']"
      }

      * If option
      if "`if'" != "" {
        local condition = "if `if'"
      }

      dis "`compare1'"

      * Compare1 option: parse type and vars when comma present
      if "`compare1'" != "" & strpos("`compare1'", ",") > 0 {
            local compare_type = substr("`compare1'", 1, strpos("`compare1'", ",") - 1)
            local compare_vars = substr("`compare1'", strpos("`compare1'", ",") + 1, .)
      }
      dis "`compare_type'"
      dis "`compare_vars'"

      * compare2 requires compare1
      if "`compare2'" != "" & ("`compare1'" == "" | "`compare1'" == "none" | "`compare1'" == "naive") {
            di as err "compare2() may only be specified when compare1() is specified and is not none/naive"
            exit 198
      }

      * Parse compare2 when specified
      if "`compare2'" != "" & strpos("`compare2'", ",") > 0 {
            local compare2_type = substr("`compare2'", 1, strpos("`compare2'", ",") - 1)
            local compare2_vars = substr("`compare2'", strpos("`compare2'", ",") + 1, .)
      }
      if "`compare2'" != "" & strpos("`compare2'", ",") == 0 {
            local compare2_type = "`compare2'"
      }

      * Just the 'naive' plot (before plot)
      if "`compare1'" == "none" | "`compare1'" == "naive" {
            local version_list = "naive"
            local fe_naive = "`fe'"
            local title0 = "No correction"
            local version_num = 1
      }

      * Naive + cftemp
      if "`compare1'" == "" | "`compare1'" == "cftemp" | "`compare_type'" == "cftemp" {
            local version_list = "naive cftemp"
            local title0 = "No correction"
            local title1 = "With counterfactual correction"
            local compare_type = "cftemp"
            local fe_naive = "`fe'"
            local fe_cftemp = "`fe'"
            local version_num = 2
      }

      * Naive + place-specific linear trends
      if "`compare_type'" == "trends" {
            local version_list = "naive trends"
            local fe_naive = "`fe'"
            local fe_trends = "`compare_vars' `fe'"
            local title0 = "No correction"
            local title1 = "With linear trends"
            local version_num = 2
      }

      * Naive + lags
      if "`compare_type'" == "lags" {
            local version_list = "naive lags"
            local title0 = "No correction"
            local title1 = "With `compare_vars' lags"
            local version_num = 2

            forval q = 1/`compare_vars' {
                  local lags = "`lags' l`q'.random_Y lag`q'*"
            }
            dis "`lags'"
      }

      * Naive + county-5year FE
      if "`compare_type'" == "5year" {
            local version_list = "naive 5year"
            local title0 = "No correction"
            local title1 = "With County-5 Year FEs"

            local fe_naive = "`fe'"
            local fe_5year = "`compare_vars'"

            local version_num = 2
      }

      * Naive, heterogeneity by baseline temperature
      if "`compare_type'" == "naive het" {
            local version_list = "naive naive"
            local condition0 = "if `compare_vars' == 0"
            local condition1 = "if `compare_vars' == 1"
            local title0 = "Below median baseline temperature"
            local title1 = "Above median baseline temperature"
            local legendhet = "size(small)"
            local version_num = 2
      }

      * cftemp, heterogeneity by baseline temperature
      if "`compare_type'" == "cftemp het" {
            local version_list = "cftemp cftemp"
            local condition0 = "if `compare_vars' == 0"
            local condition1 = "if `compare_vars' == 1"
            local title0 = "Below median baseline temperature"
            local title1 = "Above median baseline temperature"
            local legendhet = "size(small)"
            local version_num = 2
      }

      * compare2: add third version (version_num = 3); only when compare2_type is supported
      if "`compare2'" != "" {
            * Third version uses _2 suffix for fe and bins to avoid overwriting compare1
            if "`compare2_type'" == "trends" {
                  local version_num = 3
                  local fe_trends_2 = "`compare2_vars' `fe'"
                  local version_list = "`version_list' trends_2"
                  local title2 = "With linear trends"
            }
            if "`compare2_type'" == "cftemp" {
                  local version_num = 3
                  local fe_cftemp_2 = "`fe'"
                  local version_list = "`version_list' cftemp_2"
                  local title2 = "With counterfactual correction"
            }
            if "`compare2_type'" == "5year" {
                  local version_num = 3
                  local fe_5year_2 = "`compare2_vars'"
                  local version_list = "`version_list' 5year_2"
                  local title2 = "With County-5 Year FEs"
            }
            if "`compare2_type'" == "lags" {
                  local version_num = 3
                  local fe_lags_2 = "`fe'"
                  local version_list = "`version_list' lags_2"
                  local title2 = "With `compare2_vars' lags"
                  forval q = 1/`compare2_vars' {
                        local lags_2 = "`lags_2' lag2_`q'*"
                  }
            }
      }
      ******************************* Binning
      * Bin for below lower bound
      local lb_str = cond(`lb' < 0, "n`=abs(`lb')'", "`lb'") //to create the string "n#" for negative numbers
      local naive_bins = "real_under_`lb_str'"
      local cftemp_bins = "exp_under_`lb_str'"
      local bin_labels = `"1 "<`lb'" "'

      * Loop through the middle bins
      local ub_bin = `ub'-`binsize'
      local k = 2
      forvalues start = `lb'(`binsize')`ub_bin' {
            local end = `start' + `binsize'
            local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
            local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")

            local naive_bins = "`naive_bins' real_`start_label'_`end_label'"
            local cftemp_bins = "`cftemp_bins' exp_`start_label'_`end_label'"
            local bin_labels = `"`bin_labels' `k' "`start'-`end'" "'
            local k = `k' + 1
      }

      * Bin for above upper bound
	local above_str = cond(`ub' < 0, "n`=abs(`ub')'", "`ub'") //to name the bin real_over_`ub'
      local naive_bins = "`naive_bins' real_over_`above_str'"
      local cftemp_bins = "`cftemp_bins' exp_over_`above_str'"
      local bin_labels = `"`bin_labels' `k' ">`ub'" "'

      * Omit one bin
      local omit_bin   : word `omit' of `naive_bins'
      local naive_bins = subinstr("`naive_bins'", "`omit_bin'", "", .)
      local omit_bin   : word `omit' of `cftemp_bins'
      local cftemp_bins = subinstr("`cftemp_bins'", "`omit_bin'", "", .)

      * Combine for cftemp
      local cftemp_bins = "`naive_bins' `cftemp_bins'"

      * Bins are the same as naive for non-cftemp methods
      local trends_bins = "`naive_bins'"
      local 5year_bins = "`naive_bins'"

      * Bins for lags
      local lags_bins = "`naive_bins' `lags'"

      * Bins for compare2 (third version)
      local cftemp_2_bins = "`cftemp_bins'"
      local trends_2_bins = "`naive_bins'"
      local 5year_2_bins = "`naive_bins'"
      local lags_2_bins = "`naive_bins' `lags_2'"

      * Number of bins
      local binnum = (`ub' - `lb') / `binsize' + 2 //2 for the extremes
      dis "`binnum'"

      ******************************* Loop through versions
      local i = 1
      preserve
      gen varName = ""
      local restrict = 0

      * generate lags
      if "`compare_type'" == "lags" {
            xtset fips year
            foreach var in `naive_bins' {
                  forval q = 1/`compare_vars' {
                        gen lag`q'`var'  = l`q'.`var'
                  }
            }
      }
      if "`compare2_type'" == "lags" {
            xtset fips year
            foreach var in `naive_bins' {
                  forval q = 1/`compare2_vars' {
                        gen lag2_`q'`var' = l`q'.`var'
                  }
            }
      }

      foreach version in `version_list' {

            * Variable to mark bins
            gen variable`i' = _n
            replace variable`i' = . if _n > `binnum'

            * Generate variables to hold estimates
            gen coef`i' = .
            gen lb`i' = .
            gen ub`i' = .
            local x = 1
            
            * Estimate
            `regression' `yvar' ``version'_bins' `control' `weight' `condition`restrict'', absorb(`fe_`version'') cluster(`cluster')

            * Save estimates
            local r2_`version': di %4.3f `e(r2)'
            foreach var in `naive_bins' {
            
                  * save lincom values in generated variable
                  qui lincom `var'
                  replace varName = "`var'" 		if _n == `x'
                  replace coef`i' = `r(estimate)'     if _n == `x'
                  replace lb`i' = `r(lb)' 		if _n == `x'
                  replace ub`i' = `r(ub)' 		if _n == `x'
                  
                  * replace iteration variable
                  local x = `x' + 1
            }

            replace variable`i' = variable`i' + 1 if variable`i' >= `omit'
            replace variable`i' = `omit' if variable`i' == `binnum' + 1
            replace lb`i' = 0 if variable`i' == `omit'
            replace ub`i' = 0 if variable`i' == `omit'
            replace coef`i' = 0 if variable`i' == `omit'
            sort variable`i'

            local i = `i' + 1
            local restrict = `restrict' + 1
      }

      *** Plot results with and without correction together
      gen coef1_lab = string(round(coef1, 0.01), "%06.2f")

      if `version_num' == 2 {
            replace variable1 = variable1 - 0.1
            replace variable2 = variable2 + 0.1

            gen coef2_lab = string(round(coef2, 0.01), "%06.2f")
      }
      if `version_num' == 3 {
            replace variable1 = variable1 - 0.15
            replace variable2 = variable2
            replace variable3 = variable3 + 0.15

            gen coef2_lab = string(round(coef2, 0.01), "%06.2f")
            gen coef3_lab = string(round(coef3, 0.01), "%06.2f")
      }

      local outcomes = ""

      foreach outcome in mortality_1_44 mortality_45_64 mortality_ {
            local ub_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", 4,2)
            local lb_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", -4,-2)
            local int_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", 1, 0.5)
            local outcomes = "`outcomes' `outcome'"
      }

      foreach outcome in mortality_less1 {
            local ub_`outcome' = 8
            local lb_`outcome' = -1
            local int_`outcome' = 2
            local outcomes = "`outcomes' `outcome'"
      }

      foreach outcome in mortality_more65 {
            local ub_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", 8, 8)
            local lb_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", -6, -3)
            local int_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", 2, 1.5)
            local outcomes = "`outcomes' `outcome'"
      }

      foreach outcome in mortality_allAges {
            local ub_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", 6, 2)
            local lb_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", -2, -4)
            local int_`outcome' = cond("`compare_type'" == "naive het" | "`compare_type'" == "cftemp het", 2, 2)
            local outcomes = "`outcomes' `outcome'"
      }

      /* if "`outcomes'" != "" & ("`yvar'" : inlist "`outcomes'") {

            local ylabels = "`lb_`yvar''(`int_`yvar'')`ub_`yvar''"
            forval i = 1/`version_num' {
                  replace coef`i' = `ub_`yvar'' if coef`i' > `ub_`yvar''
                  replace coef`i' = `lb_`yvar'' if coef`i' < `lb_`yvar''
                  replace ub`i' = `ub_`yvar'' if ub`i' >= `ub_`yvar''
                  replace ub`i' = `lb_`yvar'' if ub`i' <= `lb_`yvar''
                  replace lb`i' = `lb_`yvar'' if lb`i' <= `lb_`yvar''
                  replace lb`i' = `ub_`yvar'' if lb`i' >= `ub_`yvar''
            }
      } */

      if `version_num' == 2 {
            graph tw (scatter coef1 variable1, color("31 88 137")) (rcap lb1 ub1 variable1, color("31 88 137")) (scatter coef2 variable2, color("155 52 58") msymbol(S)) (rcap lb2 ub2 variable2, color("155 52 58")), xlabel(`bin_labels', labsize(small) nogrid) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(`ylabels', angle(h) nogrid) legend(order(1 "`title0'" 3 "`title1'") position(6) rows(1) region(lcolor(none)) `legendhet') `graph' graphregion(color(white))
      }
      if `version_num' == 3 {
            graph tw (scatter coef1 variable1, color("31 88 137")) (rcap lb1 ub1 variable1, color("31 88 137")) (scatter coef2 variable2, color("155 52 58") msymbol(S)) (rcap lb2 ub2 variable2, color("155 52 58")) (scatter coef3 variable3, color("0 100 50") msymbol(X) msize(medlarge)) (rcap lb3 ub3 variable3, color("0 100 50")), xlabel(`bin_labels', labsize(small) nogrid) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(`ylabels', angle(h) nogrid) legend(order(1 "`title0'" 3 "`title1'" 5 "`title2'") position(6) rows(1) region(lcolor(none)) size(small) `legendhet') `graph' graphregion(color(white))
      }
      if `version_num' == 1 {
            graph tw (scatter coef1 variable1, color("31 88 137")) (rcap lb1 ub1 variable1, color("31 88 137")), xlabel(`bin_labels', labsize(small) nogrid) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(`ylabels', angle(h) nogrid) legend(order(1 "`title0'") position(6) rows(1) region(lcolor(none)) `legendhet') `graph' graphregion(color(white))
      }

      restore

	* Display notification for completion
      di as txt "Plot ready to be created."

end