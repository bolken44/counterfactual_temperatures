/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: April 2025
ACTION: Runs simulations with simulated outcome variable and real temperature data.

Requirements
- Dataset should be created with the cftemp package, so that variables for the realized number of days in each temperature bin
are named real_* and expected number of days are named exp_*.

*******************************************************************************/
cap prog drop cftemp_sim
program define cftemp_sim

      ******************************* Syntax
      syntax varlist(min=3 max=3) [, simulate(real 1000) option(real 2) outcome(string) binsize(real 5) lb(real -10) ub(real 35) omit(real 4) aweights(varlist) fe(string) cluster(varlist) control(string) compare(string) method(string) graph(string) if(string) extreme bias effect(real 0)]

      ** Parse variables from syntax. The variables must be in this order
      local temp  : word 1 of `varlist'
      local geo   : word 2 of `varlist' //think of this as `geo'
      local time : word 3 of `varlist' //think of this as year

      * Initialize all latent locals only defined under if conditions
      local regression ""
      local weight ""
      local condition ""
      local compare_type ""
      local compare_vars ""
      local version_list ""
      local naive_fe ""
      local title0 ""
      local title1 ""
      local condition0 ""
      local condition1 ""
      local legendhet ""
      local version_num = .
      local lags = ""
      local realeffect = ""
      local residualize = ""
      local coef_bins = ""

      * What is the trend in the outcome variable?
      if "`outcome'" != "" & strpos("`outcome'", ",") > 0 {    
            local outcome_method = substr("`outcome'", 1, strpos("`outcome'", ",") - 1)
            local outcome_param = strtrim(substr("`outcome'", strpos("`outcome'", ",") + 1, .))
            local slope_str = cond(`outcome_param' == -1, "neg1", "`outcome_param'")
      }
      dis "`outcome_method'"
      dis "`outcome_param'"

      if "`outcome_method'" == "" | strpos("`outcome_method'", "lin") > 0 {
            local outcome_ff = cond(`outcome_param' == 0, "`time'", "`outcome_param' * `time' * `temp'")
            local base_ff = "`time'"
      }
      if strpos("`outcome_method'", "quad") > 0 {
            local outcome_ff = "`outcome_param' * `time' * `time' * `temp'"
            local base_ff = "`time' * `time'"
      }
      if strpos("`outcome_method'", "cubic") > 0 {
            local outcome_ff = "`outcome_param' * `time' * `time' * `time' * `temp'"
            local base_ff = "`time' * `time' * `time'"
      }

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

      /* * If option
      if "`if'" != "" {
        local condition = "if `if'"
      } */

      * Extreme option
      local binform = cond("`extreme'" == "", "allbins", "extreme")

      dis "`compare'"

      * Compare option
      if "`compare'" != "" & strpos("`compare'", ",") > 0 {    
            local compare_type = substr("`compare'", 1, strpos("`compare'", ",") - 1)
            local compare_vars = substr("`compare'", strpos("`compare'", ",") + 1, .)
      }
      dis "`compare_type'"
      dis "`compare_vars'"

      if "`compare'" == "none" | "`compare'" == "naive" {
            local version_list = cond("`extreme'" == "", "naive", "extreme_naive")
            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
            local title0 = "No correction"
            local version_num = 1
      }

      if "`compare'" == "cftemp" | "`compare_type'" == "cftemp" | "`compare'" == "sim" | "`compare_type'" == "sim" {
            local version_list = cond("`extreme'" == "", "cftemp", "extreme_cftemp")
            local cftemp_fe = "`fe'"
            local extreme_cftemp_fe = "`fe'"

            local title0 = "With counterfactual correction"
            local version_num = 1
      }

      if "`compare'" == "trends" | "`compare_type'" == "trends" {
            local version_list = cond("`extreme'" == "", "trends", "extreme_trends")
            local trends_fe = "`compare_vars' `fe'"
            local extreme_trends_fe = "`compare_vars' `fe'"

            local title0 = "With linear trends"
            local version_num = 1
      }

      if "`compare_type'" == "stateyear" {
            local version_list = cond("`extreme'" == "", "stateyear", "extreme_stateyear") 
            local title0 = "With State-Year FEs"

            local stateyear_fe = "`compare_vars'"
            local extreme_stateyear_fe = "`compare_vars'"

            local version_num = 1
      }

      if "`compare_type'" == "lags" {
            local version_list = cond("`extreme'" == "", "lags", "extreme_lags") 
            local title0 = "With `compare_vars' lags"

            local lags_fe = "`fe'"
            local extreme_lags_fe = "`fe'"

            local version_num = 1
      }

      if "`compare_type'" == "5year" {
            local version_list = cond("`extreme'" == "", "5year", "extreme_5year") 
            local title0 = "With County-5 Year FEs"

            local 5year_fe = "`compare_vars'"
            local extreme_5year_fe = "`compare_vars'"

            local version_num = 1
      }

      if "`compare'" == "naive cftemp" | "`compare_type'" == "naive cftemp" {
            local version_list = cond("`extreme'" == "", "naive cftemp", "extreme_naive extreme_cftemp")
            local title0 = "No correction"
            local title1 = "With counterfactual correction"
            local version_num = 2

            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
            local cftemp_fe = "`fe'"
            local extreme_cftemp_fe = "`fe'"
      }

      if "`compare'" == "naive sim" | "`compare_type'" == "naive sim" { // sim 1
            local version_list = cond("`extreme'" == "", "naive cftemp", "extreme_naive extreme_cftemp")
            local title0 = "No correction"
            local title1 = "With counterfactual correction"
            local version_num = 2

            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
            local cftemp_fe = "`fe'"
            local extreme_cftemp_fe = "`fe'"
      }

      if "`compare_type'" == "naive stateyear" {
            local version_list = cond("`extreme'" == "", "naive stateyear", "extreme_naive extreme_stateyear")

            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
            local stateyear_fe = "`compare_vars'"
            local extreme_stateyear_fe = "`compare_vars'"

            local title0 = "No correction"
            local title1 = "With State-Year FEs"
            local version_num = 2
      }

      if "`compare_type'" == "naive trends" {
            local version_list = cond("`extreme'" == "", "naive trends", "extreme_naive extreme_trends")

            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
            local trends_fe = "`compare_vars' `fe'"
            local extreme_trends_fe = "`compare_vars' `fe'"

            local title0 = "No correction"
            local title1 = "With linear trends"
            local version_num = 2
      }

      if "`compare_type'" == "naive lags" {
            local version_list = cond("`extreme'" == "", "naive lags", "extreme_naive extreme_lags") 
            local title0 = "No correction"
            local title1 = "With `compare_vars' lags"

            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
            local lags_fe = "`fe'"
            local extreme_lags_fe = "`fe'"

            local version_num = 2
      }

      if "`compare_type'" == "naive 5year" {
            local version_list = cond("`extreme'" == "", "naive 5year", "extreme_naive extreme_5year") 
            local title0 = "No correction"
            local title1 = "With County-5 Year FEs"

            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
            local 5year_fe = "`compare_vars'"
            local extreme_5year_fe = "`compare_vars'"

            local version_num = 2
      }

      if "`compare_type'" == "naive het" {
            local version_list = cond("`extreme'" == "", "naive naive", "extreme_naive extreme_naive") 
            local condition0 = "if `compare_vars' == 0"
            local condition1 = "if `compare_vars' == 1"
            local title0 = "Below median baseline temperature"
            local title1 = "Above median baseline temperature"
            local legendhet = "size(small)"
            local version_num = 2

            local naive_fe = "`fe'"
            local extreme_naive_fe = "`fe'"
      }

      if "`compare_type'" == "cftemp het" {
            local version_list = cond("`extreme'" == "", "cftemp cftemp", "extreme_cftemp extreme_cftemp") 
            local condition0 = "if `compare_vars' == 0"
            local condition1 = "if `compare_vars' == 1"
            local title0 = "Below median baseline temperature"
            local title1 = "Above median baseline temperature"
            local legendhet = "size(small)"
            local version_num = 2
            
            local cftemp_fe = "`fe'"
            local extreme_cftemp_fe = "`fe'"
      }

      dis "`condition0'"
      dis "`condition1'"

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
	local ub_str = cond(`ub' < 0, "n`=abs(`ub')'", "`ub'") //to name the bin real_over_`ub'
      local naive_bins = "`naive_bins' real_over_`ub_str'"
      local cftemp_bins = "`cftemp_bins' exp_over_`ub_str'"
      local bin_labels = `"`bin_labels' `k' ">`ub'" "'

      * Omit one bin
      local omit_bin   : word `omit' of `naive_bins'
      local naive_bins = subinstr("`naive_bins'", "`omit_bin'", "", .)
      local omit_bin   : word `omit' of `cftemp_bins'
      local cftemp_bins = subinstr("`cftemp_bins'", "`omit_bin'", "", .)

      * Extreme bins
      local extreme_naive_bins = "real_over_`ub_str' real_under_`lb_str'"
      local extreme_cftemp = "exp_over_`ub_str' exp_under_`lb_str'" //this is needed to residualize Y

      * Combine for cftemp
      local cftemp_bins = "`naive_bins' `cftemp_bins'"
      local extreme_cftemp_bins = "`extreme_naive_bins' `extreme_cftemp'"

      * Bins are the same as naive for linear trends
      local trends_bins = "`naive_bins'"
      local extreme_trends_bins = "`extreme_naive_bins'"

      * Bins are the same as naive for state-year FEs
      local stateyear_bins = "`naive_bins'"
      local extreme_stateyear_bins = "`extreme_naive_bins'"

      * Bins are the same as naive for county-5 year FEs
      local 5year_bins = "`naive_bins'"
      local extreme_5year_bins = "`extreme_naive_bins'"

      * Number of bins
      local binnum = (`ub' - `lb') / `binsize' + 2 //2 for the extremes
      dis "`binnum'"

      * Real effects
      local realeffect = " + `effect' * real_under_`lb_str' + `effect' * real_over_`ub_str'"

      *************************** Simulations
      tempfile tempfile
      save `tempfile'

      * generate variables to fill
      gen varName = ""
      gen loop = .
      gen coef = .
      gen tstat = .
      gen se = .
      gen varNum = .
      gen pValue = .
      gen trend_Y = .
      gen bias = .
      foreach bin in under_`lb_str' over_`ub_str' {
            gen slope_`bin' = .
            gen se_`bin' =  .
            gen sigma_`bin' = .
            gen resid_`bin' = .
      }
      gen sigma_T0 = .

      * Normalize year to start at 1
      sum `time'
      replace `time' = `time' - `r(min)' + 1
      xtset `geo' `time'

      * Make sure temperature is in F
      /* if "${source}" == "era5_F" {
            replace `temp' = (`temp' * 9 / 5) + 32 // convert to F (only for ERA 5)
      } */

      * Save temperature std deviation
      gen temp = `base_ff' * `temp'
      sum temp

      local halfStdDevValue 		= `r(sd)'/2
      local oneStdDevValue 		= `r(sd)'
      local twoStdDevValue	 	= `r(sd)'*2
      local fourStdDevValue	 	= `r(sd)'*4

      drop temp

      * Number of days in year
      if `option' == 1 {
            
            * Number of days per unit of panel
            egen numdays = rowtotal(real_*)
            /* egen numdays = rowtotal(under_* temp_* over_*) */
            sum numdays
            local maxdays = `r(max)'
      }

      * generate lags
      if strpos("`compare'", "lags") > 0 {
            local coef_bins = cond("`extreme'" == "", "`naive_bins'", "`extreme_naive_bins'")
            foreach var in `coef_bins' {
                  forval q = 1/`compare_vars' {
                        gen lag`q'`var'  = l`q'.`var'
                  }
            }
            local lags = ""
            forval q = 1/`compare_vars' {
                  local lags = "`lags' l`q'.random_Y lag`q'*"
            }
            dis "`lags'"

            * Bins for lags
            local lags_bins = "`naive_bins' `lags'"
            local extreme_lags_bins = "`extreme_naive_bins' `lags'"
      }

      * loop through versions and lists
      local i = 1 // i denotes version
      foreach version in `version_list' {

            * set iteration variable
            local x = 1 // x denotes bin (gets reset for each version)

            if strpos("`compare_type'", "het") > 0 { // for adaptation loop
                  local restrict = `i' - 1 // restrict is 0 or 1
            }

            * run regression many times 
            forvalues l = 1/`simulate' {
                  
                  * Temperature Variable
                  quietly {
                        if `option' == 1 {

                              gen simYearlyTemp = `temp' if `time' == 1
                              bysort `geo': replace simYearlyTemp = l.simYearlyTemp + 9/(5*50) if l.simYearlyTemp != .

                              * Simulate daily temperatures for the realized bins
                              sum `temp'
                              local tempstddev = 9 //`r(sd)'
                              forvalues d = 1/`maxdays'{
                                    gen tempDay`d' = rnormal(simYearlyTemp, `tempstddev')
                                    replace tempDay`d' = . if numdays < `d'

                                    * Create bin for below lower bound
                                    cap gen real_under_`lb_str' = 0
                                    replace real_under_`lb_str' = real_under_`lb_str' + (tempDay`d' < `lb')
                                    
                                    * Loop through the middle bins
                                    forvalues start = `lb'(`binsize')`ub_bin' {
                                          local end = `start' + `binsize'
                                          
                                          local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
                                          local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")

                                          cap gen real_`start_label'_`end_label' = 0
                                          replace real_`start_label'_`end_label' = real_`start_label'_`end_label' + (tempDay`d' >= `start' & tempDay`d' < `end')
                                    }

                                    * Create bin for above upper bound
                                    cap gen real_over_`ub_str' = 0
                                    replace real_over_`ub_str' = real_over_`ub_str' + (tempDay`d' >= `ub')
                              }

                              * Simulate expected temperature bins
                              if strpos("`compare_type'", "sim") > 0 {
                                    drop exp_*

                                    cap gen exp_under_`lb_str' = 0
                                    replace exp_under_`lb_str' = numdays * (normal((`lb'-simYearlyTemp)/`tempstddev'))

                                    forvalues start = `lb'(`binsize')`ub_bin' {
                                          local end = `start' + `binsize'
                                          
                                          local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
                                          local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")

                                          cap gen exp_`start_label'_`end_label' = 0
                                          replace exp_`start_label'_`end_label' = numdays * (normal((`end'-simYearlyTemp)/`tempstddev') - normal((`start'-simYearlyTemp)/`tempstddev'))
                                    }

                                    cap gen exp_over_`ub_str' = 0
                                    replace exp_over_`ub_str' = numdays * (1 - normal((`ub'-simYearlyTemp)/`tempstddev'))
                              }

                        }
                  }

                  * random variable with mean 0 and std dev v^2
                  dis "`outcome_ff'"
                  dis "`realeffect'"
                  gen random_Y = `outcome_ff' + rnormal(0,`twoStdDevValue') `realeffect'

                  * regression
                  `regression' random_Y ``version'_bins' `control' `weight' `condition`restrict'', absorb(``version'_fe') cluster(`cluster')

                  * save variables
                  local coef_bins = cond("`extreme'" == "", "`naive_bins'", "`extreme_naive_bins'")
                  foreach var in `coef_bins' {

                        qui lincom `var'
                        replace varName = "`var'" 		if _n == `x'
                        replace varNum 	= `x'*`l' 		if _n == `x'
                        replace coef 	= `r(estimate)'   if _n == `x'
                        replace tstat	= `r(t)' 		if _n == `x'
                        replace se        = `r(se)'         if _n == `x'
                        replace pValue 	= `r(p)' 		if _n == `x'
                        replace loop 	= `l'			if _n == `x'

                        local x = `x' + 1
                  }

                  * compute trends on Y
                  if `option' == 2 & "`bias'" != "" {
                        
                        tempfile save
                        save `save', replace

                        //residualize
                        local residualize = cond(strpos("`compare'", "cftemp") > 0, "`extreme_cftemp'", cond(strpos("`compare'", "lags") > 0, "`lags'", ""))
                        dis "`residualize'"

                        reghdfe random_Y `residualize' `control', absorb(``version'_fe') cluster(`geo') resid(resid)

                        //time trends
                        /* levelsof `geo', local(fips_code)
                        gen coefs = .
                        foreach fip in `fips_code' {
                              regress resid `time' if `geo' == `fip'
                              replace coefs = _b[`time'] if `geo' == `fip'
                        } */
                        
                        statsby _b, by(`geo') clear: regress resid `time'
                        rename _b_`time' coefs
                        tempfile coef
                        save `coef', replace
                        
                        // merge time trends with baseline temp
                        use `save', clear
                        merge m:1 `geo' using `coef', nogen
                        
                        keep coefs baselinePeriodTemp
                        duplicates drop

                        //correlation with baseline temperature
                        regress coefs baselinePeriodTemp
                        local slope_Y = _b[baselinePeriodTemp]

                        // save correlation
                        use `save', clear
                        replace trend_Y = `slope_Y' if _n == (2 * `l') | _n == (2 * `l') - 1 // l denotes simulation count
                  }

                  * drop randomly generated variables to draw again
                  drop random_Y
                  if `option' == 1 {
                        drop simYearlyTemp tempDay* real*
                  }

            }

            * coefficients and tstats of the main sim coefficient
            foreach var in `coef_bins' {
                  foreach stat in coef tstat {
                        gen meanCoef = `stat'
                        replace meanCoef = . if varName != "`var'"
                        _pctile meanCoef, nq(1000)
                        local `stat'_p25_`var' = `r(r25)'
                        local `stat'_p975_`var' = `r(r975)'
                        local `stat'_p500_`var' = `r(r500)'

                        drop meanCoef
                  }
            }

            * Bias Table
            if `option' == 2 & "`bias'" != "" {
                  
                  // save omega Y
                  _pctile trend_Y, nq(1000)
                  global coef_p500_`i'_Y = `r(r500)'
                  global coef_p25_`i'_Y = string(round(`r(r25)', 0.00001))
                  global coef_p975_`i'_Y = string(round(`r(r975)', 0.00001))

                  global coef_`i'_Y_str = string(round(`r(r500)', 0.00001))
                  global coef_`i'_Y_ci = "[${coef_p25_`i'_Y}, ${coef_p975_`i'_Y}]"
                  
                  // exclude Y variables from lags
                  if strpos("`compare'", "lags") > 0 {
                        local lags = ""
                        forval q = 1/`compare_vars' {
                              local lags = "`lags' lag`q'*"
                        }
                        dis "`lags'"
                  }

                  // calculate omega C and H
                  foreach bin in under_`lb_str' over_`ub_str' {
                        
                        tempfile save
                        save `save', replace

                        // residualize
                        local residualize = cond(strpos("`compare'", "cftemp") > 0, "`extreme_cftemp'", cond(strpos("`compare'", "lags") > 0, "`lags'", ""))

                        reghdfe real_`bin' `residualize' `control', absorb(``version'_fe') cluster(`geo') resid(resid)

                        // trends
                        statsby _b, by(`geo') clear: regress resid `time'
                        rename _b_`time' coefs
                        tempfile coef
                        save `coef', replace
                        
                        // merge trends with baseline temperature 
                        use `save', clear
                        merge m:1 `geo' using `coef', nogen
                        keep coefs baselinePeriodTemp
                        duplicates drop

                        // get correlation and stats for the bias formula
                        regress coefs baselinePeriodTemp
                        global slope_`bin' = _b[baselinePeriodTemp]
                        global slope_`bin'_str : display %9.0g ${slope_`bin'}

                        global slope2_`bin' = _b[baselinePeriodTemp]^2
                        global slope2_`bin'_str : display %9.0g ${slope2_`bin'}

                        local se_`bin' =  _se[baselinePeriodTemp]
                        local lb_`bin'    = string(_b[baselinePeriodTemp] - 1.96 * _se[baselinePeriodTemp], "%9.0g")
                        local ub_`bin'    = string(_b[baselinePeriodTemp] + 1.96 * _se[baselinePeriodTemp], "%9.0g")
                        global trend_ci_`bin' = "[`lb_`bin'', `ub_`bin'']"

                        global resid_`bin' = e(rss)/e(df_r)
                        global resid_`bin'_str = string(e(rss)/e(df_r), "%9.0g")

                        // variance of baseline temperature
                        sum baselinePeriodTemp
                        global sigma_T0 = r(sd)
                        global sigma2_T0_str = string(round(${sigma_T0}^2, 0.01))
                        dis "Inside: ${sigma_T0}"

                        * Back to dataset
                        use `save', clear
                        
                        * Variance of the bins
                        sum real_`bin'
                        local sigma_`bin' = r(sd)

                        replace slope_`bin' = ${slope_`bin'}
                        replace se_`bin' =  `se_`bin''
                        replace sigma_`bin' = `sigma_`bin''
                        replace resid_`bin' = ${resid_`bin'}
                        replace sigma_T0 = ${sigma_T0}
                        local include = "`include' slope_`bin' se_`bin' sigma_`bin' resid_`bin'"
                  }
                  
                  * Under bin
                  local num_C1 = (${slope_over_`ub_str'})^2 * ${sigma_T0}^2 + ${resid_over_`ub_str'} + 0.0012 * `sigma_over_`ub_str''^2
                  local num_C2 = ${slope_under_`lb_str'} * ${sigma_T0}^2
                  local num_C3 = ${slope_under_`lb_str'} * ${slope_over_`ub_str'} * ${sigma_T0}^2
                  local num_C4 = ${slope_over_`ub_str'} * ${sigma_T0}^2
                  local num_C_all = `num_C1' * `num_C2' - `num_C3' * `num_C4'

                  * Over bin
                  local num_H1 = (${slope_under_`lb_str'})^2 * ${sigma_T0}^2 + ${resid_under_`lb_str'} + 0.0012 * `sigma_under_`lb_str''^2
                  local num_H2 = ${slope_over_`ub_str'} * ${sigma_T0}^2
                  local num_H3 = ${slope_over_`ub_str'} * ${slope_under_`lb_str'} * ${sigma_T0}^2
                  local num_H4 = ${slope_under_`lb_str'} * ${sigma_T0}^2
                  local num_H_all = `num_H1' * `num_H2' - `num_H3' * `num_H4'

                  * Denominators
                  local denom_C = `num_H1' * `num_C1' - (`num_C3')^2
                  local denom_H = `num_C1' * `num_H1' - (`num_H3')^2
                  dis $coef_p500_1_Y

                  * Bias
                  global bias2_under_`lb_str' = string(`num_C_all' * $coef_p500_1_Y / `denom_C', "%9.0g")
                  global bias2_over_`ub_str'= string(`num_H_all' * $coef_p500_1_Y / `denom_H', "%9.0g")
                  dis "${bias2_over_`ub_str'}"

                  replace bias = `num_C_all' * trend_Y / `denom_C' if varName == "real_under_`lb_str'" 
                  replace bias = `num_H_all' * trend_Y / `denom_H' if varName == "real_over_`ub_str'"
                  dis "${bias2_over_`ub_str'}"
                  local include = "`include' sigma_T0 bias"
            }

            * save all simulation runs to folder
            preserve
            keep varName varNum coef se tstat pValue loop trend_Y `include'
            dis "${bias2_over_`ub_str'}"
            gen method = "${method}"
            gen source = "${source}"
            duplicates drop
            drop if varName == ""
            order source method varName varNum coef se tstat pValue trend_Y `include' loop

            if `effect' == 0 {
                  export delimited "${temp}cftemp_${source}_`outcome_method'_`binform'_${task}.csv", replace
            }
            else {
                  export delimited "${temp}cftemp_${source}_`outcome_method'_effect`effect'_`binform'_${task}.csv", replace
            }
            restore

            * graph evolution of coefficients
            gen variable`i' = _n
            replace variable`i' = . if variable`i' > `binnum'
            
            foreach var in p500 p25 p975 {
                  gen coef_`var'_`i' = .
                  local k = 1
                  foreach bin in `coef_bins' {
                        local place = cond(`k' >= `omit', `k' + 1, `k')
                        replace coef_`var'_`i' = `coef_`var'_`bin'' if variable`i' == `place'
                        local k = `k' + 1
                  }
                  replace coef_`var'_`i' = 0 if variable`i' == `omit'

                  * Store top and bottom bin as globals to include in table
                  foreach stat in coef tstat {
                        global `stat'_`var'_`i'_under_`lb_str' = string(round(``stat'_`var'_real_under_`lb_str'', 0.00001))
                        global `stat'_`var'_`i'_over_`ub_str' = string(round(``stat'_`var'_real_over_`ub_str'', 0.00001))
                  }

            }

            local i = `i' + 1

      }

      *************************** Plotting
      /* gen coef1_lab = string(round(coef_1, 0.01), "%06.2f") */

      if "`extreme'" == "" {
            if `version_num' == 2 {
                  replace variable1 = variable1 - 0.1
                  replace variable2 = variable2 + 0.1

                  /* gen coef2_lab = string(round(coef_2, 0.01), "%06.2f") */

                  graph tw (scatter coef_p500_1 variable1, color("31 88 137")) (rcap coef_p25_1 coef_p975_1 variable1, color("31 88 137")) (scatter coef_p500_2 variable2, color("155 52 58")) (rcap coef_p25_2 coef_p975_2 variable2, color("155 52 58")), xlabel(`bin_labels', labsize(small) nogrid) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(`ylabels', angle(h) nogrid) legend(order(1 "`title0'" 3 "`title1'") position(6) rows(1) region(lcolor(none)) `legendhet') `graph' graphregion(color(white) lcolor(none))
            }

            if `version_num' == 1 {
                  graph tw (scatter coef_p500_1 variable1, color("31 88 137")) (rcap coef_p25_1 coef_p975_1 variable1, color("31 88 137")), xlabel(`bin_labels', labsize(small) nogrid) xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(`ylabels', angle(h) nogrid) legend(order(1 "`title0'") position(6) rows(1) region(lcolor(none)) `legendhet') `graph' graphregion(color(white) lcolor(none))
            }

            if `effect' == 0 {
                  graph export "${simulations}sim`option'/sim`option'_`outcome_method'`slope_str'_${source}_${method}.pdf", replace
            }
            else {
                  graph export "${simulations}sim`option'/sim`option'_`outcome_method'`slope_str'_effect`effect'_${source}_${method}.pdf", replace
            }

            * Display notification for completion
            di as txt "Simulation plot ready to be created."
      }

      use `tempfile', clear

      * Display notification for completion
      di as txt "Simulation results exported as csv."

end