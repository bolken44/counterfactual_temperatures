/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Generate counterfactual temperatures

UPDATE: Cristine von Dessauer
DATE: May 2025
ACTION: Extract slopes for each place

Requirements
- Dataset should have a temperature variable at the level of a geographic unit (e.g., fips) and the finest time level (e.g., day)
- Dataset should have a variable indexing the first and second aggregated time level (e.g., month and year)

*******************************************************************************/

program define cftemp_slope_base
    /* version 18.0 */

    * Catch the syntax.
    syntax varlist(min=4 max=4) [, binsize(real 5) lb(real -10) ub(real 35) agg(varlist) realonly]
    
	/* quietly { */
		
		** Parse variables from syntax. The variables must be in this order
		local temp  : word 1 of `varlist'
		local geo   : word 2 of `varlist' //think of this as fips
		local time1 : word 3 of `varlist' //think of this as month
		local time2 : word 4 of `varlist' //think of this as year

		** Make the necessary time variables
		local agg_time = cond(`agg' == `time2', "", "`time1'")
		/* This is the unit of time for which trends are separately calculated.
		If user wants the dataset returned at the month level, then this local
		is set to month. If user wants the data returned at the year level, then
		this local is empty, since trends will then be computed by geographic unit only. */
		dis "`agg_time'"
		egen uni_time = group(`time2' `agg_time')
		dis "`agg_time'"
		/* This is the unit of time at which user wants the dataset returned.
		If 'month' is specified in agg(), this codes a unique signifier
		for each year-month. This will simply be year if agg(year). */
		
		** Realized Temperature Bins
		/* This should be at the level of fip and the level of the return dataset, so
		compute everything by `geo' uni_time. Name the bins in the following format:
		- real_under_# for the lowest bin
		- real_#1_#2 for the middle bins
		- real_over_# for the highest bin
		in the counterfactual bins below, simply switch "real_" to "exp_".
		When the numbers are negative, write n#. So if lb(-10), the first bin is "real_under_n10". */

			* Create bin for below lower bound
			local lb_str = cond(`lb' < 0, "n`=abs(`lb')'", "`lb'") //to create the string "n#" for negative numbers
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
			local above_str = cond(`ub' < 0, "n`=abs(`ub')'", "`ub'") //to name the bin real_over_`ub'
			bysort `geo' uni_time: egen real_over_`above_str' = sum(`temp' >= `ub')
		
		** If realonly is specified, only return the realized bins
		if "`realonly'" != "" {
			local return_list = "real_*"
		}

		** Counterfactual Temperature Bins
		if "`realonly'" == "" {
			* Set of variables to return
			local return_list = "real_* exp_*"

			* Average temperature for time1 across time2 by geographic unit
			bysort `geo' `time1' `time2': egen avg_temp = mean(`temp')
			
			* Average temperature for time2 by geographic unit
			bysort `geo' `time2': egen avg_temp_year = mean(`temp')
			
			* Estimate slopes of average time1 temperature change across time2 by geographic unit
			/* We only want one observation per geo-time1-time2 in the regression with the mean temperature,
			so we code 'unique' to pick this observation. */
			
			gen slope = .
			
			bysort `time1' `time2' `geo': gen unique = _n == 1
			bysort `time2' `geo': gen uniqueByYear = _n == 1
			
			* Loop through all geographic units and all values of `time1' (e.g., 12 months)
			levelsof `geo', local(geocode)
			sum `time1'
			local maxtime1 = `r(max)'
			local mintime1 = `r(min)'
			
			* Regress and save the slope at time1-geo level (e.g., month-fip)
			foreach g in `geocode' {
												
				* estimate regressions and slopes for splines
				forvalues t = `mintime1'/`maxtime1' {
					* estimating slope coefficients
					regress avg_temp `time2' 		if `time1' == `t' & `geo' == `g' & unique == 1
					replace slope = _b[`time2'] 		if `time1' == `t' & `geo' == `g'
				}
			}
			
			drop unique uniqueByYear
		}
		
	/* } */
	
	* Display notification for completion
	if "`realonly'" != "" {
		di as txt "Realized bin variables created successfully."
	}
	if "`realonly'" == "" {
		di as txt "Realized and counterfactual bin variables created successfully."
	}

end
