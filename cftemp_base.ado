/*******************************************************************************
STATA COMMAND cftemp (version 1.0)

AUTHOR: Harufumi Nakazawa
DATE: March 2025
LAST UPDATE: September 24, 2025
ACTION: Generate counterfactual temperatures

This file and cftemp.ado should be stored in the same folder, and the folder path should be stored in a global `path`:
global path "<folder path>"

Requirements
- Dataset should have a temperature variable at the level of a geographic unit (e.g., fips) and the finest time level (e.g., day)
- Dataset should have a variable indexing the first and second aggregated time level (e.g., month and year)

Run `help cftemp` or see our README file for more details.

*******************************************************************************/

program define cftemp_base

    * Catch the syntax.
    syntax varlist(min=4 max=4) [, binsize(real 5) lb(real -10) ub(real 35) time(varlist) keep(varlist) trend(string) bayes(string) realonly]
    
	quietly {
		
		** Parse variables from syntax. Variables must be in this order
		local temp  : word 1 of `varlist'
		local geo   : word 2 of `varlist' // think of this as fips
		local time1 : word 3 of `varlist' // think of this as month
		local time2 : word 4 of `varlist' // think of this as year

		* Make geo numeric
		cap confirm variable geo_num
		if _rc { //if it does not exist, create
			egen geo_num = group(`geo')
			local geo_orig `geo'
			local geo geo_num
			local keep "`keep' `geo_orig'"
		}

		* Time relative to the first time2 (e.g., first year becomes 0)
		egen mintime2 = min(`time2')
		gen event_`time2' = `time2' - mintime2

		*******************************************************************************/
		** Special Options
		
		* Empirical Bayes
		/* All parameters of the counterfactual temperature model are first estimated
		for each geographic unit `geo' separately. bayes(mean, [geographic variable]) specifies
		that these parameters be shrunk toward the average of that parameter for `geo' units 
		within the specified [geographic variable], presumed to be a larger geographic unit than `geo'.
		In particular, bayes(mean, all) specifies that the parameters be shrunk toward the
		average of all geographic units.
		The shrinkage is by inverse-variance weighting.

		bayes(zero) specifies that the parameters be shrunk toward zero.
		*/
		if "`bayes'" == "" {
			local bayes "mean, all"
		}
		else if "`bayes'" == "none" {
			local bayes ""
		}
		
		if "`bayes'" != "" & strpos("`bayes'", ",") > 0 {    
			local bayes_ff = substr("`bayes'", 1, strpos("`bayes'", ",") - 1)
			local bayes_param = substr("`bayes'", strpos("`bayes'", ",") + 1, .)
		}

		*******************************************************************************/
		* Linear trends
		/* The trend() option specifies the counterfactual temperature model.
		
		trend(time2) is the default and specifies that the average temperature of 
		each time1-geo is linearly regressed against time2.

		trend(chebyshev, #) specifies that the counterfactual temperature model is a #-th order
		Chebyshev polynomial interacted with time2 trends.
		*/

		if "`trend'" != "" & strpos("`trend'", ",") > 0 {    
			local trend_ff = substr("`trend'", 1, strpos("`trend'", ",") - 1)
			local trend_param = substr("`trend'", strpos("`trend'", ",") + 1, .)
		}
		
		* Linear trend in year  - this is the default if trend() is not specified
		if "`trend'" == "`time2'" | "`trend'" == "" {
			local trendvar = "event_`time2'"
			local mintrendvar = "mintime2"
		}

		* Chebyshev polynomials in day of year, to the nth order (specified in trend_param)
		if strpos("`trend_ff'", "cheb") > 0 {
			cap drop date*
			gen date = mdy(month, day, year)
			gen doy = doy(date)
			bysort year: egen doymax = max(doy)
			gen x = 2 * (doy - 1) / (doymax - 1) - 1
 
			* Generate Chebyshev polynomials of degree 0 to `trend_param'
			gen T0 = 1
			gen T1 = x

			local regressor = ""
			forval n = 2/`trend_param' {
				local n1 = `n' - 1
				local n2 = `n' - 2
				gen T`n' = 2 * x * T`n1' - T`n2'
			}
			forval n = 0/`trend_param' {
				gen T`n'_trend = T`n' * event_`time2'
				local regressor = "`regressor' T`n' T`n'_trend" //
			}
			
			* Generate the constraint (odd-order polynomials should sum to 0)
			local expr ""
			local expr_trend ""
			
			forval i = 1(2)`trend_param' {
			    local expr "`expr' T`i' +"
			    local expr_trend "`expr_trend' T`i'_trend +"
			}
			local expr = substr("`expr'", 1, length("`expr'")-2) // remove the trailing plus sign
			local expr_trend = substr("`expr_trend'", 1, length("`expr_trend'")-2) // remove the trailing plus sign
			
			constraint 1 `expr' = 0
			constraint 2 `expr_trend' = 0

			local trendvar = "event_`time2'"
			local mintrendvar = "mintime2"
			drop date x
		}

		*******************************************************************************/
		** Make the necessary time variables

		local agg_time = cond(`time' == `time2', "", "`time1'")
		/* This is the unit of time for which trends are separately calculated. If the user wants the dataset returned at the month level, then this local will be set to month. If the user wants the data returned at the year level, then this local will be empty, since trends will then be computed by geographic unit only. */
		
		egen uni_time = group(`time2' `agg_time')
		/* This is the unit of time at which the user wants the dataset returned. If 'month' is specified in time(), this codes a unique signifier for each year-month. This will simply be year if time(year). */
		
		*******************************************************************************/
		** Realized Temperature Bins
		/* This should be at the level of `geo' and the temporal level of the return dataset. So we compute everything bysort `geo' uni_time. 
		
		The bins are named in the following format:
		- real_under_# for the lowest bin
		- real_#1_#2 for the middle bins
		- real_over_# for the highest bin
		In naming the counterfactual bins below, the prefix "real_" becomes "exp_".
		Negative temperatures are written n#. So if lb(-10), the first bin is "real_under_n10". */

			* Create bin for below lower bound
			local lb_str = cond(`lb' < 0, "n`=abs(`lb')'", "`lb'") // to create the string "n#" for negative numbers
			bysort `geo' uni_time: egen real_under_`lb_str' = sum(`temp' < `lb')
			
			* Loop through the middle bins
			local ub_bin = `ub'-`binsize'
			forvalues start = `lb'(`binsize')`ub_bin' {
				local end = `start' + `binsize'
				
				local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
				local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")
				
				bysort `geo' uni_time: egen real_`start_label'_`end_label' = ///
					sum(`temp' >= `start' & `temp' < `end')
			}
			
			* Create bin for above upper bound
			local ub_str = cond(`ub' < 0, "n`=abs(`ub')'", "`ub'") // to name the bin real_over_`ub'
			bysort `geo' uni_time: egen real_over_`ub_str' = sum(`temp' >= `ub')
		
		** If realonly is specified, only return the realized bins
		if "`realonly'" != "" {
			local return_list = "real_*"
		}

		*******************************************************************************/
		** Counterfactual Temperature Bins
		if "`realonly'" == "" {
			* Set of variables to return
			local return_list = "real_* exp_*"

			*******************************************************************************/
			*** The Regression

			* Loop through all geographic units and all values of `time1' (e.g., 12 months)
			levelsof `geo', local(geocode)
			sum `time1'
			local maxtime1 = `r(max)'
			local mintime1 = `r(min)'

			****************************************
			* Linear trends
			if strpos("`trend_ff'", "cheb") <= 0 {
				* Average temperature for time1-time2 by geographic unit
				bysort `geo' `time1' `time2': egen avg_temp = mean(`temp')

				/* We only want one observation per geo-time1-time2 in the regression with the mean temperature,
				so we code 'unique' to pick this observation. */
				gen slope = .
				gen SE = .
				bysort `time1' `time2' `geo': gen unique = _n == 1
				
				* Regress and save the slope at time1-geo level (e.g., month-fip)
				foreach g in `geocode' {

					forvalues t = `mintime1'/`maxtime1' {

						regress avg_temp `trendvar' if `time1' == `t' & `geo' == `g' & unique == 1 // & `time2'_count > 1
						replace slope = _b[`trendvar'] if `time1' == `t' & `geo' == `g' // & `time2'_count > 1
						matrix V = e(V)
						scalar se = sqrt(V[1,1])
						replace SE = se if `time1' == `t' & `geo' == `g' // & `time2'_count > 1
					}
				}
				drop unique

				* For empirical Bayes, shrink toward the mean slope by month
				if strpos("`bayes'", "mean") > 0  {
					bysort `time1': egen mean_slope = mean(slope) // prior
					gen variance = SE^2
					sum slope, detail
					scalar slope_var = r(sd)^2
					gen w = slope_var / (slope_var + variance)
					replace slope = w * slope + (1-w) * mean_slope
				}

				* Subtract the slope to detrend
				gen detrendedTemp = `temp' - slope  * `trendvar' // if `time2'_count > 1
			}
			
			************************************
			* Chebyshev Polynomials
			if strpos("`trend_ff'", "cheb") > 0 {
				local trend_sum = ""
				forval n = 0/`trend_param' {
					gen slope_`n' = .
					gen SE_`n' = .
					local trend_sum = "`trend_sum' - slope_`n' * T`n'_trend"
				}

				* Regress
				foreach g in `geocode' {
					cnsreg `temp' `regressor' if doy != doymax & `geo' == `g', constraint(1-2) nocons

					matrix V = e(V)
					forval n = 0/`trend_param' {
						local 2n = 2 * (`n' + 1)
						replace slope_`n' = _b[T`n'_trend] if `geo' == `g' 
						scalar se = sqrt(V[`2n',`2n'])
						replace SE_`n' = se if `geo' == `g'
					}
				}

				* For empirical Bayes, shrink toward the mean slope by year
				if strpos("`bayes'", "mean") > 0  {
					
					forval n = 0/`trend_param' {
						bysort `time2': egen mean_slope_`n' = mean(slope_`n') // prior

						gen variance = SE_`n'^2
						sum slope_`n', detail
						scalar slope_`n'_var = r(sd)^2
						gen w = slope_`n'_var / (slope_`n'_var + variance)

						replace slope_`n' = w * slope_`n' + (1-w) * mean_slope_`n'
						drop variance w
					}
				}

				* Subtract the slope to detrend
				gen detrendedTemp = `temp' + `trend_sum'
			}
			
			*******************************************************************************/
			*** The Binning

			* Loop through the trend variable and move the aggregate distribution one slope at a time
			/* e.g., if the trend variable is time2, for each `geo' `agg_time' (e.g., fip-month), 
			all daily observations of detrended temperatures are aggregated to make one big empirical 
			distribution of temperatures in that month for that location. Then we count the number of observations 
			that fall into each bin - it has not been scaled yet to add up correctly to the number
			of days in the level to return the dataset (year/month). At the end of the loop, add
			the slope back to detrendedTemp for all observations ONCE to shift the aggregate distribution
			for the next value of time2. The procedure for naming the bins is the same as explained for 
			realized temperatures above. */

			sort event_`time2'
			levelsof event_`time2', local(event_`time2'values)
			foreach y of local event_`time2'values {

				* Add one slope back to the aggregate distribution
				if strpos("`trend_ff'", "cheb") <= 0 {
					gen retrendvar = .
					replace retrendvar = `trendvar' if event_`time2' == `y'
					bysort `geo' `time1': ereplace retrendvar = max(retrendvar)
					sum retrendvar
					local retrend_sum = "+ slope * retrendvar"
					gen retrendedTemp = detrendedTemp `retrend_sum' 
				}
				else if strpos("`trend_ff'", "cheb") > 0 {
					local retrend_sum = ""
					forval n = 0/`trend_param' {
						local retrend_sum = "`retrend_sum' + slope_`n' * T`n' * `y'"
					}
					gen retrendedTemp = detrendedTemp `retrend_sum' 
				}
				dis "`retrend_sum'"

				* Create variables for below lower bound
				cap gen exp_under_`lb_str' = .
				bysort `geo' `agg_time': egen temp_sum = total(retrendedTemp < `lb' & retrendedTemp != .)
				replace exp_under_`lb_str' = temp_sum if event_`time2' == `y'
				drop temp_sum
				
				* Loop through bins
				forvalues start = `lb'(`binsize')`ub_bin' {
					local end = `start' + `binsize'
					local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
					local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")
					
					cap gen exp_`start_label'_`end_label' = .
					bysort `geo' `agg_time': egen temp_sum = total(retrendedTemp >= `start' & retrendedTemp < `end' & retrendedTemp != .)
					replace exp_`start_label'_`end_label' = temp_sum if event_`time2' == `y'
					drop temp_sum
				}
				
				* Create variable for above upper bound
				cap gen exp_over_`ub_str' = .
				bysort `geo' `agg_time': egen temp_sum = total(retrendedTemp >= `ub' & retrendedTemp != .)
				replace exp_over_`ub_str' = temp_sum if event_`time2' == `y'

				* Drop variables for next iteration of loop
				drop temp_sum retrendedTemp
				cap drop retrendvar
				
			}
		
			** Scale to add up to the correct number of days
			egen aggdays = rowtotal(exp_*)
			egen numdays = rowtotal(real_*) // actual # of days in that year for fip or fip-month. This accounts for leap months/years

			foreach var of varlist exp_* {
				replace `var' = numdays * `var' / aggdays
			}
		
		}
		
		** Organize and return
		/* Once we keep only the relevant variables, all of the (daily) observations in the
		geographic unit - return time level are redundant. Drop those duplicates. */
		keep `geo_orig' `agg_time' `time2' `return_list' `keep'
		duplicates drop
		order `geo_orig' `time2' `agg_time', first
		sort `geo_orig' `time2' `agg_time'
	}
	
	*******************************************************************************/
	* Display notification for completion
	if "`realonly'" != "" {
		di as txt "Realized bin variables created successfully."
	}
	if "`realonly'" == "" {
		di as txt "Realized and counterfactual bin variables created successfully."
	}

end
