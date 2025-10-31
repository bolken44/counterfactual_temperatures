# Stata command `cftemp`

version: 1.1 (October 30, 2025)

The `cftemp` program takes a panel dataset with some fine temporal variation in temperature (say, place-day level) and transforms it to an aggregated panel dataset (say, place-year level) with variables holding the *realized* and *expected* number of days that fall into each temperature bin, the bounds and interval of which are specified by the user.

Under the default syntax, the counterfactual (expected number of days) is calculated using yearly trends in temperature for each place-month WITH empirical Bayesian shrinkage toward the mean for all geographic units.

```
cftemp avg_temp_day fips month year, binsize(5) lb(-10) ub(35) time(year)
```

This will categorize the `avg_temp_day` variable into temperature bins ranging from -10 to 35 degrees, using bins of 5 degrees, and produce a fips-year level dataset that holds the number of realized and expected days in the year that observe temperatures in each bin.

Specifying `time(month)` will instead return a fips-year-month level dataset with the number of days in each month for each bin.

After applying this command, the dataset is ready to be used for regression analysis using the standard binning specification, e.g.,
```
reghdfe outcome real_under_n10-real_15-20 real_25-30-real_over_35 exp_*, absorb(fips year) cluster(fips)
```
which would estimate the effects of each temperature bin on the outcome variable relative to the 20-25 degree bin.

The theory and empirical applications are developed in our paper ["With or Without U? Binning Bias and the Causal Effects of Temperature Shocks"](https://www.dropbox.com/scl/fi/1ya6zzb76g0eayicexr2g/U_Shapes_Paper.pdf?rlkey=rkwfyw4m8iecn1uasrnasaz1m&e=7&st=b5cwqvs7&dl=0) by Benjamin F. Jones, Jacob Moscona, Benjamin A. Olken, and Cristine von Dessauer.

## Installation

There are two files: `cftemp_base.ado` and `cftemp.ado`. The substantive file is `cftemp_base.ado`, while `cftemp.ado` is simply a wrapper for the former to allow for parallelization. The two should be stored in the same folder, and that folder path should be stored in a global `ado`:
```
  global ado "<folder path>"
```

Then add
```
  run "${ado}cftemp.ado"
```
to your code before you use this command. This sets up both ado files to be used in your code. The first step of defining the global `ado` is necessary because the code `${ado}cftemp_base.ado` is already inside `cftemp.ado`. 
  

## Syntax

Dataset should be at the level of the geographic unit and the finest temporal unit with temperature data (e.g., county-day level).

```
cftemp temp geo time1 time2, [binsize(#) lb(#) ub(#) time(var) trend(string) bayes(string) parallel(#)]
```

**Required arguments:**
- `temp` - The variable holding temperature data.
- `geo` - The variable uniquely indexing the geographic unit.
- `time1` - The time variable for which temperature distributions are calculated separately (e.g., month)
- `time2` - The time variable across which temperature is assumed to follow a linear trend (e.g., year)

## Options

### Temperature bin settings
- `binsize(#)` - The size of temperature bins. Default is 5.
- `lb(#)` - The lower bound of the temperature range. Default is -10.
- `ub(#)` - The upper bound of the temperature range. Default is 35.

### Temporal Aggregation settings
- `time(var)` - The variable used for aggregation. Default is `year`. Note that there must already exist a variable with that name in the dataset.

### Functional form settings
- `bayes(string)` - All parameters of the counterfactual temperature model are first estimated for each geographic unit separately. The `bayes()` option allows for empirical Bayes shrinkage of these parameters. The shrinkage is performed using inverse-variance weighting.
  - `bayes(mean, all)` - Shrinks parameters toward the average of all geographic units. This is the default.
  - `bayes(none)` - Turns off empirical shrinkage.
  - `bayes(mean, geovar)` - Shrinks parameters toward the average of that parameter within the specified geographic variable (presumed to be a larger geographic unit than the dataset, e.g., `geovar` can be states if `geo` is county).
  - `bayes(zero)` - Shrinks parameters toward zero.

- `trend(string)` - Specifies the counterfactual temperature model. Default is `trend(time2)`.
  - `trend(time2)` - The average temperature of each time1-geo is linearly regressed against time2.
  - `trend(chebyshev, #)` - The counterfactual temperature model is a #-th order Chebyshev polynomial interacted with time2 trends for more flexible modeling of temperature trends.

### Parallelization settings
- `parallel(#)` - Specifies the number of clusters for parallel processing. If omitted, no parallelization is used. The program will run parallelized by the geographic unit, with the computations distributed across `(#)` CPU cores. This uses the user-written command `parallel`.

### Miscellaneous
- `keep(string)` - Specifies variables that are already in the dataset and should be kept in the return dataset. The most obvious use case is to precompute the average temperature at the return dataset level (say, county-year level) and keep that variable using `keep(avg_temp)`.
- `realonly` - Returns a dataset with only the realized temperature bins, not the expected counts. This is useful when you only need the observed temperature distribution and do not require a counterfactual temperature distribution.

## Output dataset

The variables holding realized frequencies will be named as:
- `real_under_<lower bound>` and `real_over_<upper bound>` for the edge bins
- `real_<bin lower bound>_<bin upper bound>` for all other bins

The variables holding expected (counterfactual) frequencies will be named as:
- `exp_under_<lower bound>` and `exp_over_<upper bound>` for the edge bins
- `exp_<bin lower bound>_<bin upper bound>` for all other bins


## Edit History
- version 1.1: The counterfactual binning did not work unless the trend option was specified. Updated to make trend(time2) truly the default.