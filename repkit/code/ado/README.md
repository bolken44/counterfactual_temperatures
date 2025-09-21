# Stata command `cftemp`

The `cftemp` program takes a panel dataset with some fine temporal variation in temperature (say, place-day level) and transforms it to an aggregated panel dataset (say, place-year level) with variables holding the *realized* and *expected* number of days that fall in each of a user-specified set of temperature bins.

The theory and empirical applications are developed in our paper ["With or Without U? Binning Bias and the Causal Effects of Temperature Shocks"](https://www.dropbox.com/scl/fi/1ya6zzb76g0eayicexr2g/U_Shapes_Paper.pdf?rlkey=rkwfyw4m8iecn1uasrnasaz1m&e=7&st=b5cwqvs7&dl=0) by Benjamin F. Jones, Jacob Moscona, Benjamin A. Olken, and Cristine von Dessauer.


## Syntax

Dataset should be at the level of the geographic unit and the finest temporal unit with temperature data (e.g., county-day level).

```
cftemp tempvar geovar timevar1 timevar2 [, binsize(#) lb(#) ub(#) time(var) parallel(#)]
```

**Required arguments:**
- `tempvar` - The variable holding temperature data.
- `geovar` - The variable uniquely indexing the geographic unit.
- `timevar1` - The time variable for which temperature distributions are calculated separately (e.g., month)
- `timevar2` - The time variable across which temperature is assumed to follow a linear trend (e.g., year)

## Options

### Temperature bin settings
- `binsize(#)` - The size of temperature bins. Default is 5.
- `lb(#)` - The lower bound of the temperature range. Default is -10.
- `ub(#)` - The upper bound of the temperature range. Default is 35.

### Temporal Aggregation settings
- `time(var)` - The variable used for aggregation. Default is `year`.

### Functional form settings
- `bayes(string)` - All parameters of the counterfactual temperature model are first estimated for each geographic unit separately. The `bayes()` option allows for empirical Bayes shrinkage of these parameters. The shrinkage is performed using inverse-variance weighting.
  - `bayes(mean, all)` - Shrinks parameters toward the average of all geographic units. This is the default.
  - `bayes(none)` - Turns off empirical shrinkage.
  - `bayes(mean, geovar)` - Shrinks parameters toward the average of that parameter within the specified geographic variable (presumed to be a larger geographic unit, e.g., states if `geovar` is county).
  - `bayes(zero)` - Shrinks parameters toward zero.

- `trend(string)` - Specifies the counterfactual temperature model. Default is `trend(time2)`.
  - `trend(time2)` - The average temperature of each time1-geo is linearly regressed against time2.
  - `trend(chebyshev, #)` - The counterfactual temperature model is a #-th order Chebyshev polynomial interacted with time2 trends for more flexible modeling of temperature trends.

### Miscellaneous
- `keep(string)` - Specifies variables that are already in the dataset and should be kept in the return dataset. This is particularly useful for keeping precomputed variables at the aggregation level. The most obvious use case is to precompute the average temperature at the return dataset level (say, county-year level) and keep that variable using `keep(avg_temp)`.
- `realonly` - Returns a dataset with only the realized temperature bins, not the expected counts. This is useful when you only need the observed temperature distribution and do not require the counterfactual analysis.

### Parallelization settings
- `parallel(#)` - Specifies the number of clusters for parallel processing. If omitted, no parallelization is used. The program will run parallelized by the geographic unit, with the computations distributed across `(#)` CPU cores. This uses the user-written command `parallel`.

## Description

The variables holding realized frequencies will be named as:
- real_under_<lower bound> and real_over_<upper bound> for the edge bins
- real_<bin lower bound>_<bin upper bound> for all other bins

The variables holding expected (counterfactual) frequencies will be named as:
- exp_under_<lower bound> and exp_over_<upper bound> for the edge bins
- exp_<bin lower bound>_<bin upper bound> for all other bins

## Example

```
cftemp avg_temp_day fips month year, binsize(5) lb(-10) ub(35) agg(year)
```

This will categorize the `avg_temp_day` variable into temperature bins ranging from -10 to 35 degrees, using bins of 5 degrees, and produce a fips-year level dataset that holds the number of realized and expected days in the year that observe temperatures in each bin.

Specifying `agg(month)` will instead return a fips-year-month level dataset with the number of days in each month for each bin.
