/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: March 2025
ACTION: Generate counterfactual temperatures

This command is a wrapper for the original function, now stored as cftemp_base.ado,
that takes the (strictly optional) option 'parallel' specifying the number of CPUs.
It utilizes the ssc command 'parallel' to parallelize the code at the geographic unit level.

Requirements (same as cftemp_base.ado)
- Dataset should have a temperature variable at the level of a geographic unit (e.g., fips) and the finest time level (e.g., day)
- Dataset should have a variable indexing the first and second aggregated time level (e.g., month and year)

*******************************************************************************/
cap prog drop cftemp
cap prog drop cftemp_base
qui run "${path}/Haru/cftemp/cftemp_base.ado"

program define cftemp
    /* version 18.0 */
    syntax varlist(min=4 max=4) [, binsize(real 5) lb(real -10) ub(real 35) time(varlist) realonly parallel(real 0) keep(string) trend(string) bayes(string) splines  aggregate(real 5)]
	
	* If the parallel option is specified, set the specified number of CPUs and run parallelized by the geographic unit
	if `parallel' > 0 {
		/* quietly { */
			ssc install parallel
			parallel clean
			parallel setclusters `parallel'
			local geo   : word 2 of `varlist'

			** Make geo numeric
			egen geo_num = group(`geo')
			local geo_orig "`geo'"
			local geo "geo_num"
			sort geo_num
		
		parallel, by(geo_num) programs(cftemp_base): cftemp_base `varlist', binsize(`binsize') lb(`lb') ub(`ub') time(`time') keep(`geo_orig' `keep') `realonly' trend(`trend') bayes(`bayes') `splines' aggregate(`aggregate')
		/* parallel clean */
		/* } */
	}
	
	* If the parallel option is not specified, simply run all geographic units
	else {
		cftemp_base `varlist', binsize(`binsize') lb(`lb') ub(`ub') time(`time') `realonly' trend(`trend') bayes(`bayes') `splines' aggregate(`aggregate')
	}
end
