*******************************************************
* 1. Load or prepare your dataset with:
*    - daily temperature (`temp`)
*    - day-of-year (`day`, from 1 to 365)
*    - year (e.g., 2000–2024)
*******************************************************

global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

log using "${path}Haru/log/chebyshev_fit.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

use "${path}/DTA_US/countyLevel_US_1970_2019.dta", clear

foreach fip in 25025 4013 {

      preserve
      keep if fips == `fip'

      keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
      reshape long avg_temp_daytime avg_temp_day, i(fips year  latitude longitude month) j(day)
      drop latitude longitude
      drop if avg_temp_daytime == .
      replace avg_temp_daytime = (avg_temp_daytime * 9 / 5) + 32

      * Center year for numerical stability
      sum year
      local minyear = r(min)
      gen year0 = year - `minyear'

      * Rescale day to [-1, 1]
      gen date = mdy(month, day, year)
      gen doy = doy(date) // extract the day of the year (1-365 or 366)
      bysort year: egen doymax = max(doy)
	gen x = 2 * (doy - 1) / (doymax - 1) - 1

      * Generate Chebyshev polynomials of degree 0 to 4
      gen T0 = 1
      gen T1 = x
      gen T2 = 2 * x * T1 - T0
      gen T3 = 2 * x * T2 - T1
      gen T4 = 2 * x * T3 - T2

      * Interactions
      gen T0y = T0 * year0
      gen T1y = T1 * year0
      gen T2y = T2 * year0
      gen T3y = T3 * year0
      gen T4y = T4 * year0

      * Fit model with Chebyshev polynomials and their interactions with year
      /* On jan1, x = -1. so T0 = 1, T1 = -1, T2 = 2 * -1 * -1 - 1 = 1
      T3 = 2 * -1 * 1 - -1 = -1, T4 = 2 * -1 * -1 - 1 = 1
      On dec31, x = 1, so T0 = 1, T1 = 1, T2 = 2 * 1 * 1 - 1 = 1,
      T3 = 2 * 1 * 1 - 1 = 1
      */
      /* local i = 1
      levelsof year0, local(year0values)
      foreach y of local year0values {
            constraint `i' T1 + T3 + (T1y + T3y) * `y' = 0
            local i = `i' + 1
      } */
      constraint 1 T1 + T3 = 0
      constraint 2 T1y + T3y = 0

      cnsreg avg_temp_daytime T0 T1 T2 T3 T4 T0y T1y T2y T3y T4y if day != doymax, constraint(1,2) nocons

      * Save coefficients
      matrix b = e(b)

      *******************************************************
      * 2. Build a new dataset to plot predicted curves
      *******************************************************

      clear
      set obs 365
      
      * Expand to 3 selected years
      expand 3
      gen year = .
      replace year = 1970 in 1/365
      replace year = 1990 in 366/730
      replace year = 2015 in 731/1095

      bysort year: gen day = _n
      gen x = 2 * (day - 1) / (365 - 1) - 1

      * Generate Chebyshev polynomials
      gen T0 = 1
      gen T1 = x
      gen T2 = 2 * x * T1 - T0
      gen T3 = 2 * x * T2 - T1
      gen T4 = 2 * x * T3 - T2
      
      gen year0 = year - `minyear'

      * Interactions
      gen T0y = T0 * year0
      gen T1y = T1 * year0
      gen T2y = T2 * year0
      gen T3y = T3 * year0
      gen T4y = T4 * year0

      * Get predicted values using coefficients from regression
      gen pred_temp = ///
            b[1,1]*T0 + b[1,2]*T1 + b[1,3]*T2 + b[1,4]*T3 + b[1,5]*T4 ///
      + b[1,6]*T0y + b[1,7]*T1y + b[1,8]*T2y + b[1,9]*T3y + b[1,10]*T4y

      list pred_temp day if day == 1 | day == 365

      *******************************************************
      * 3. Plot predicted seasonal curves
      *******************************************************
      twoway ///
            (line pred_temp day if year==1970, lcolor(blue)) ///
            (line pred_temp day if year==1990, lcolor(green)) ///
            (line pred_temp day if year==2015, lcolor(red)) ///
            , legend(order(1 "1970" 2 "1990" 3 "2015")) ///
            title("Estimated Seasonal Temperature Trends") ///
            ytitle("Predicted Temperature") ///
            xtitle("Day of Year")
      graph export "${output}checks/chebyshev/fit_`fip'_era5_F.pdf", replace

      restore
}