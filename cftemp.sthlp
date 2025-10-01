{smcl}
{hline}

{title:Title:}

{phang}
{bf:cftemp} {hline 2} Create realized and counterfactual temperature bin variables

{phang}
version: 1.0 (September 24, 2025)

{phang}
The `cftemp` program takes a panel dataset with some fine temporal variation in temperature (say, place-day level) and transforms it to an aggregated panel dataset (say, place-year level) with variables holding the {it:realized} and {it:expected} number of days that fall into each temperature bin, the bounds and interval of which are specified by the user.

{phang}
Under the default syntax, the counterfactual (expected number of days) is calculated using yearly trends in temperature for each place-month WITH empirical Bayesian shrinkage toward the mean for all geographic units.

{hline}

{title:Installation:}

{phang}
There are two files: `cftemp_base.ado` and `cftemp.ado`. The substantive file is `cftemp_base.ado`, while `cftemp.ado` is simply a wrapper for the former to allow for parallelization. The two should be stored in the same folder, and that folder path should be stored in a global `ado`:
{p_end}
{phang}
{space 2}{bf:global ado "<folder path>"}
{p_end}

{phang}
Then add
{p_end}
{phang}
{space 2}{bf:run "${ado}cftemp.ado"}
{p_end}
{phang}
to your code before you use this command. This sets up both ado files to be used in your code. The first step of defining the global `ado` is necessary because the code `${ado}cftemp_base.ado` is already inside `cftemp.ado`.
{p_end}

{hline}

{title:Example:}
{p 8 17 2}
{cmdab:cftemp} avg_temp_day fips month year, binsize(5) lb(-10) ub(35) time(year)

{phang}
This will categorize the `avg_temp_day` variable into temperature bins ranging from -10 to 35 degrees, using bins of 5 degrees, and produce a fips-year level dataset that holds the number of realized and expected days in the year that observe temperatures in each bin. {p_end}

{phang}
Specifying {bf:time(month)} will instead return a fips-year-month level dataset with the number of days in each month for each bin. {p_end}

{phang}
After applying this command, the dataset is ready to be used for regression analysis using the standard binning specification, e.g.,
{p_end}
{p 8 17 2}
{cmdab:reghdfe} outcome real_under_n10-real_15-20 real_25-30-real_over_35 exp_*, absorb(fips year) cluster(fips)

{phang}
which would estimate the effects of each temperature bin on the outcome variable relative to the 20-25 degree bin. {p_end}

{hline}

{title:Syntax:}
{phang}
Dataset should be at the level of the geographic unit and the finest temporal unit with temperature data (e.g., county-day level).

{p 8 17 2}
{cmdab:cftemp} {it:temp} {it:geo} {it:time1} {it:time2}, [{opt binsize(#)} {opt lb(#)} {opt ub(#)} {opt time(var)} {opt trend(string)} {opt bayes(string)} {opt parallel(#)} {opt keep(string)} {opt realonly}]

{synoptset 15 tabbed}
{synopt:{opt temp}} The variable holding temperature data. {p_end}
{synopt:{opt geo}} The variable uniquely indexing the geographic unit. {p_end}
{synopt:{opt time1}} The time variable for which temperature distributions are calculated separately (e.g., month) {p_end}
{synopt:{opt time2}} The time variable across which temperature is assumed to follow a linear trend (e.g., year) {p_end}

{title:Options:}
{synoptset 15 tabbed}
{synopthdr}
{synoptline}

{syntab:Temperature bin settings}
{synopt:{opt binsize(#)}} The size of temperature bins. Default is 5. {p_end}
{synopt:{opt lb(#)}} The lower bound of the temperature range. Default is -10. {p_end}
{synopt:{opt ub(#)}} The upper bound of the temperature range. Default is 35. {p_end}

{syntab:Temporal Aggregation settings}
{synopt:{opt time(var)}} The variable used for aggregation. Default is `year`. Note that there must already exist a variable with that name in the dataset. {p_end}

{syntab:Functional form settings}
{synopt:{opt bayes(string)}} All parameters of the counterfactual temperature model are first estimated for each geographic unit separately. The {bf:bayes()} option allows for empirical Bayes shrinkage of these parameters. The shrinkage is performed using inverse-variance weighting. {p_end}
{synopt:{space 4}{opt bayes(mean, all)}} Shrinks parameters toward the average of all geographic units. This is the default. {p_end}
{synopt:{space 4}{opt bayes(none)}} Turns off empirical shrinkage. {p_end}
{synopt:{space 4}{opt bayes(mean, geovar)}} Shrinks parameters toward the average of that parameter within the specified geographic variable (presumed to be a larger geographic unit than the dataset, e.g., `geovar` can be states if `geo` is county). {p_end}
{synopt:{space 4}{opt bayes(zero)}} Shrinks parameters toward zero. {p_end}

{synopt:{opt trend(string)}} Specifies the counterfactual temperature model. Default is {opt trend(time2)}. {p_end}
{synopt:{space 4}{opt trend(time2)}} The average temperature of each time1-geo is linearly regressed against time2. {p_end}
{synopt:{space 4}{opt trend(chebyshev, #)}} The counterfactual temperature model is a #-th order Chebyshev polynomial interacted with time2 trends for more flexible modeling of temperature trends. {p_end}

{syntab:Parallelization settings}
{synopt:{opt parallel(#)}} Specifies the number of clusters for parallel processing. If omitted, no parallelization is used. The program will run parallelized by the geographic unit, with the computations distributed across {bf:(#)} CPU cores. This uses the user-written command {cmdab:parallel}. {p_end}

{syntab:Miscellaneous}
{synopt:{opt keep(string)}} Specifies variables that are already in the dataset and should be kept in the return dataset. The most obvious use case is to precompute the average temperature at the return dataset level (say, county-year level) and keep that variable using {bf:keep(avg_temp)}. {p_end}
{synopt:{opt realonly}} Returns a dataset with only the realized temperature bins, not the expected counts. This is useful when you only need the observed temperature distribution and do not require a counterfactual temperature distribution. {p_end}

{hline}

{title:Output dataset:}

{phang}
The variables holding realized frequencies will be named as: {p_end}
{phang}
- `real_under_<lower bound>` and `real_over_<upper bound>` for the edge bins {p_end}
{phang}
- `real_<bin lower bound>_<bin upper bound>` for all other bins {p_end}

{phang}
The variables holding expected (counterfactual) frequencies will be named as: {p_end}
{phang}
- `exp_under_<lower bound>` and `exp_over_<upper bound>` for the edge bins {p_end}
{phang}
- `exp_<bin lower bound>_<bin upper bound>` for all other bins {p_end}

{hline}

{title:Theory:}

{phang}
The theory and empirical applications are developed in our paper "With or Without U? Binning Bias and the Causal Effects of Temperature Shocks" by Benjamin F. Jones, Jacob Moscona, Benjamin A. Olken, and Cristine von Dessauer.
{p_end}

{hline}
