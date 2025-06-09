/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Generate counterfactual temperatures

AUTHOR: Cristine von Dessauer
DATE: March 2025
ACTION: Update command such that it estimates counterfactuals with a spline in optimal place for each county

Requirements
- Dataset should have a temperature variable at the level of a geographic unit (e.g., fips) and the finest time level (e.g., day)
- Dataset should have a variable indexing the first and second aggregated time level (e.g., month and year)

*******************************************************************************/

program define cftemp_spline_base
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
			
			* Estimate slopes (around kink) of average time1 temperature change across time2 by geographic unit
			/* We only want one observation per geo-time1-time2 in the regression with the mean temperature,
			so we code 'unique' to pick this observation. */
			
			gen slope0 = 0
			gen slope1 = 0
			gen slope2 = 0
			gen slope3 = 0
			gen slope4 = 0
			gen slope5 = 0
			
			gen spline1 = 0
			gen spline2 = 0
			gen spline3 = 0
			gen spline4 = 0
			gen spline5 = 0
			
			gen knot1 = .
			gen knot2 = .
			gen knot3 = .
			gen knot4 = .
			gen knot5 = .
			
			gen num_breaks = .
			
			bysort `time1' `time2' `geo': gen unique = _n == 1
			bysort `time2' `geo': gen uniqueByYear = _n == 1
			
			* Loop through all geographic units and all values of `time1' (e.g., 12 months)
			levelsof `geo', local(geocode)
			sum `time1'
			local maxtime1 = `r(max)'
			local mintime1 = `r(min)'
			
			* Regress and save the slope at time1-geo level (e.g., month-fip)
			foreach g in `geocode' {
				
				preserve
					keep if uniqueByYear == 1 & `geo' == `g'
					xtset `geo' `time2'
					
					* first find optimal number of kinks
					xtbreak avg_temp_year `time2'
					
					local num_breaks = e(num_breaks)
					
					* second, if at least one break, find location of those breaks
					xtbreak estimate avg_temp_year `time2', breaks(`num_breaks')
					
					* store knot locations based on number of optimal breaks
					if `num_breaks' == 0 {
						local knot1 = .
						local knot2 = .
						local knot3 = .
						local knot4 = .
						local knot5 = .
					}
					else if `num_breaks' == 1 {
						matrix kink = e(breaks)
						local knot1 = kink[2,1]
						local knot2 = .
						local knot3 = .
						local knot4 = .
						local knot5 = .
					}
					else if `num_breaks' == 2 {
						matrix kink = e(breaks)
						local knot1 = kink[2,1]
						local knot2 = kink[2,2]
						local knot3 = .
						local knot4 = .
						local knot5 = .
					}
					else if `num_breaks' == 3 {
						matrix kink = e(breaks)
						local knot1 = kink[2,1]
						local knot2 = kink[2,2]
						local knot3 = kink[2,3]
						local knot4 = .
						local knot5 = .
					}
					else if `num_breaks' == 4 {
						matrix kink = e(breaks)
						local knot1 = kink[2,1]
						local knot2 = kink[2,2]
						local knot3 = kink[2,3]
						local knot4 = kink[2,4]
						local knot5 = .
					}
					else if `num_breaks' == 5 {
						matrix kink = e(breaks)
						local knot1 = kink[2,1]
						local knot2 = kink[2,2]
						local knot3 = kink[2,3]
						local knot4 = kink[2,4]
						local knot5 = kink[2,5]
					}
				restore
				
				* store knots and number of breaks for each fips
				replace knot1 =  `knot1' 		if `geo' == `g'
				replace knot2 =  `knot2' 		if `geo' == `g'
				replace knot3 =  `knot3' 		if `geo' == `g'
				replace knot4 =  `knot4' 		if `geo' == `g'
				replace knot5 =  `knot5' 		if `geo' == `g'
				
				replace num_breaks = `num_breaks' 	if `geo' == `g'
				
				* make spline for those kinks and store splines
				if `num_breaks' == 1 {
					makespline linear `time2' 	if `geo' == `g', knotslist(`knot1') replace
					replace spline1 = _sp_1_1 	if `geo' == `g'
				}
				else if `num_breaks' == 2 {
					makespline linear `time2' 	if `geo' == `g', knotslist(`knot1' `knot2') replace
					replace spline1 = _sp_1_1 	if `geo' == `g'
					replace spline2 = _sp_1_2 	if `geo' == `g'
				}
				else if `num_breaks' == 3 {
					makespline linear `time2' 	if `geo' == `g', knotslist(`knot1' `knot2' `knot3') replace
					replace spline1 = _sp_1_1 	if `geo' == `g'
					replace spline2 = _sp_1_2 	if `geo' == `g'
					replace spline3 = _sp_1_3 	if `geo' == `g'
				}
				else if `num_breaks' == 4 {
					makespline linear `time2' 	if `geo' == `g', knotslist(`knot1' `knot2' `knot3' `knot4') replace
					replace spline1 = _sp_1_1 	if `geo' == `g'
					replace spline2 = _sp_1_2 	if `geo' == `g'
					replace spline3 = _sp_1_3 	if `geo' == `g'
					replace spline4 = _sp_1_4 	if `geo' == `g'
				}
				else if `num_breaks' == 5 {
					makespline linear `time2' 	if `geo' == `g', knotslist(`knot1' `knot2' `knot3' `knot4' `knot5') replace
					replace spline1 = _sp_1_1 	if `geo' == `g'
					replace spline2 = _sp_1_2 	if `geo' == `g'
					replace spline3 = _sp_1_3 	if `geo' == `g'
					replace spline4 = _sp_1_4 	if `geo' == `g'
					replace spline5 = _sp_1_5 	if `geo' == `g'
				}
				
				* estimate regressions and slopes for splines
				forvalues t = `mintime1'/`maxtime1' {
					* estimating spline coefficients
					if `num_breaks' == 0{
						regress avg_temp `time2' 		if `time1' == `t' & `geo' == `g' & unique == 1
						replace slope0 = _b[`time2'] 		if `time1' == `t' & `geo' == `g'
					}
					else if `num_breaks' == 1{
						regress avg_temp `time2' _sp_1_1	if `time1' == `t' & `geo' == `g' & unique == 1
						replace slope0 = _b[`time2'] 		if `time1' == `t' & `geo' == `g'
						replace slope1 = _b[_sp_1_1] 		if `time1' == `t' & `geo' == `g'
					}
					else if `num_breaks' == 2{
						regress avg_temp `time2' _sp_1_1 _sp_1_2 if `time1' == `t' & `geo' == `g' & unique == 1
						replace slope0 = _b[`time2'] 		if `time1' == `t' & `geo' == `g'
						replace slope1 = _b[_sp_1_1] 		if `time1' == `t' & `geo' == `g'
						replace slope2 = _b[_sp_1_2] 		if `time1' == `t' & `geo' == `g'
					}
					else if `num_breaks' == 3{
						regress avg_temp `time2' _sp_1_1 _sp_1_2 _sp_1_3 if `time1' == `t' & `geo' == `g' & unique == 1
						replace slope0 = _b[`time2'] 		if `time1' == `t' & `geo' == `g'
						replace slope1 = _b[_sp_1_1] 		if `time1' == `t' & `geo' == `g'
						replace slope2 = _b[_sp_1_2] 		if `time1' == `t' & `geo' == `g'
						replace slope3 = _b[_sp_1_3] 		if `time1' == `t' & `geo' == `g'
					}
					else if `num_breaks' == 4{
						regress avg_temp `time2' _sp_1_1 _sp_1_2 _sp_1_3 _sp_1_4 if `time1' == `t' & `geo' == `g' & unique == 1
						replace slope0 = _b[`time2'] 		if `time1' == `t' & `geo' == `g'
						replace slope1 = _b[_sp_1_1] 		if `time1' == `t' & `geo' == `g'
						replace slope2 = _b[_sp_1_2] 		if `time1' == `t' & `geo' == `g'
						replace slope3 = _b[_sp_1_3] 		if `time1' == `t' & `geo' == `g'
						replace slope4 = _b[_sp_1_4] 		if `time1' == `t' & `geo' == `g'
					}
					else if `num_breaks' == 5{
						regress avg_temp `time2' _sp_1_1 _sp_1_2 _sp_1_3 _sp_1_4 _sp_1_5 if `time1' == `t' & `geo' == `g' & unique == 1
						replace slope0 = _b[`time2'] 		if `time1' == `t' & `geo' == `g'
						replace slope1 = _b[_sp_1_1] 		if `time1' == `t' & `geo' == `g'
						replace slope2 = _b[_sp_1_2] 		if `time1' == `t' & `geo' == `g'
						replace slope3 = _b[_sp_1_3] 		if `time1' == `t' & `geo' == `g'
						replace slope4 = _b[_sp_1_4] 		if `time1' == `t' & `geo' == `g'
						replace slope5 = _b[_sp_1_5] 		if `time1' == `t' & `geo' == `g'
					}
				}
			}
			
			drop unique uniqueByYear
			
			* Time relative to the first time2 (e.g., first year becomes 0)
			egen mintime2 = min(`time2')
			gen event_`time2' = `time2' - mintime2

			* Subtract the slope to detrend			
			gen detrendedTemp = .
				replace detrendedTemp = `temp' - slope0 * event_`time2' - slope1 * spline1 - slope2 * spline2 - slope3 * spline3 - slope4 * spline4 - slope5 * spline5
			drop mintime2
			
			* Loop through time2 and add up the aggregate distribution
			/* Loop at the level of the larger time variable (time2, year). For each `geo' `agg_time'
			(e.g., fip-month), all daily observations of detrended temperatures are aggregated to make one
			big empirical distribution of temperatures in that month for that location. Count the number of
			observations that fall into each bin - it has not been scaled yet to add up correctly to the number
			of days in the level to return the dataset (year/month). At the end of the loop, add
			the slope back to detrendedTemp for all observations ONCE to shift the aggregate distribution
			for the next value of time2. The procedure for naming the bins is the same as explained for 
			realized temperatures above. */

			levelsof `time2', local(`time2'values)
			foreach y of local `time2'values {
				
				* Create variables for below lower bound
				cap gen exp_under_`lb_str' = .
				bysort `geo' `agg_time': egen temp_sum = total(detrendedTemp < `lb')
				replace exp_under_`lb_str' = temp_sum if `time2' == `y'
				drop temp_sum
				
				* Loop through bins
				forvalues start = `lb'(`binsize')`ub_bin' {
					local end = `start' + `binsize'
					local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
					local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")
					
					cap gen exp_`start_label'_`end_label' = .
					bysort `geo' `agg_time': egen temp_sum = total(detrendedTemp >= `start' & detrendedTemp < `end')
					replace exp_`start_label'_`end_label' = temp_sum if `time2' == `y'
					drop temp_sum
				}
				
				* Create variable for above upper bound
				cap gen exp_over_`above_str' = .
				bysort `geo' `agg_time': egen temp_sum = total(detrendedTemp >= `ub')
				replace exp_over_`above_str' = temp_sum if `time2' == `y'
				drop temp_sum
				
				* Add one slope back to the aggregate distribution (depending on position around kinks)
				replace detrendedTemp = detrendedTemp + slope0 + slope1 * (`y' > knot1) ///
							+ slope2 * (`y' > knot2) + slope3 * (`y' > knot3) ///
							+ slope4 * (`y' > knot4) + slope5 * (`y' > knot5)
			}
		
			** Scale to add up to the correct number of days
			bysort `geo' `agg_time': gen N = _N //total # of days at fip or fip-month across all years
			egen numdays = rowtotal(real_*) //actual # of days in that year for fip or fip-month. This accounts for leap months/years

			foreach var of varlist exp_* {
				replace `var' = numdays * `var' / N
			}

		}
		
		** Organize and return
		/* Once we keep only the relevant variables, all of the (daily) observations in the
		geographic unit - return time level are redundant. Drop those duplicates. */
		keep `geo' `agg_time' `time2' `return_list' knot* num_breaks
		duplicates drop
		order `geo' `time2' `agg_time', first
		sort `geo' `time2' `agg_time'
	/* } */
	
	* Display notification for completion
	if "`realonly'" != "" {
		di as txt "Realized bin variables created successfully."
	}
	if "`realonly'" == "" {
		di as txt "Realized and counterfactual bin variables created successfully."
	}

end
