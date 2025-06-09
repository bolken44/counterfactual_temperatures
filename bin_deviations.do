/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: April 2025
ACTION: All simulation 2.
*******************************************************************************/

clear all
set more off
/* set scheme modern */

ssc install ppmlhdfe
ssc install ereplace

global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

********************************************************************************
** Dechenes and Greenstone +65 Estimates Plot for Ben's Presentation
********************************************************************************
/* set obs 10
gen var1 = _n
generate var2 = 3.438 in 1
replace var2 = 2.408 in 2
replace var2 = 1.116 in 9
replace var2 = 5.219 in 10

generate var3 = 1.378 in 1
replace var3 = 1.101 in 2
replace var3 = 0.920 in 9
replace var3 = 1.416 in 10

rename var2 coef
rename var3 se

gen lb = coef - se * 1.96
gen ub = coef + se * 1.96

graph tw (scatter coef var1, color("31 88 137")) (rcap lb ub var1, color("155 52 58")), xlabel(1 "<10" 2 "10-20" 3 "20-30" 4 "30-40" 5 "40-50" 6 "50-60" 7 "60-70" 8 "70-80" 9 "80-90" 10 ">90", labsize(small))  xtitle("") yline(0, lpattern(dash) lcolor(red)) ylabel(-2(2)8, angle(h)) legend(order(2 "2.5 - 97.5 pctile") position(6))
graph export "${output}simulation3_mortality_more65_paper.pdf", replace */

********************************************************************************
** ADD WEATHER DATA
********************************************************************************
local data_era5 = "${weather}era5_UScounty_1970_2019_cftemp.dta"
local data_month_era5 = "${weather}era5_monthly_UScounty_1970_2019_cftemp.dta"
local bins_era5 = "binsize(5) lb(-10) ub(35) omit(6)"

local data_era5_F = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"
local bins_era5_F = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_naive = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F_naive = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"
local bins_era5_F_naive = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_bayes = "${weather}era5_UScounty_1970_2019_cftemp_F_bayes.dta"
local data_month_era5_F_bayes = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_bayes.dta"
local bins_era5_F_bayes = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_splines = "${weather}era5_UScounty_1970_2019_cftemp_F_splines.dta"
local data_month_era5_F_splines = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_splines.dta"
local bins_era5_F_splines = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_avgtrend = "${weather}era5_UScounty_1970_2019_cftemp_F_avgtrend.dta"
local data_month_era5_F_avgtrend = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_avgtrend.dta"
local bins_era5_F_avgtrend = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_avgtrend_bayes = "${weather}era5_UScounty_1970_2019_cftemp_F_avgtrend_bayes.dta"
/* local data_month_era5_F_avgtrend_bayes = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_avgtrend_bayes.dta" */
local bins_era5_F_avgtrend_bayes = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_chebyshev = "${weather}era5_UScounty_1970_2019_cftemp_F_chebyshev.dta"
local data_month_era5_F_chebyshev = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_chebyshev.dta"
local bins_era5_F_chebyshev = "binsize(10) lb(10) ub(90) omit(6)"

local data_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp.dta"
local prcp_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp_prcp.dta"
local data_month_ghcn = "${weather}ghcn_monthly_UScounty_1968_2002_cftemp.dta"
local prcp_month_ghcn = "${weather}ghcn_monthly_UScounty_1968_2002_cftemp_prcp.dta"
local bins_ghcn = "binsize(10) lb(10) ub(90) omit(6)"

local data_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp.dta"
local prcp_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp_prcp.dta"
local data_month_ghcn_ext = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp.dta"
local prcp_month_ghcn_ext = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp_prcp.dta"
local bins_ghcn_ext = "binsize(10) lb(10) ub(90) omit(6)"

local data_schlenker = "${weather}schlenker_UScounty_1950_2019_cftemp.dta"
local data_month_schlenker = "${weather}schlenker_UScounty_1950_2019_cftemp.dta"
local bins_schlenker = "binsize(5) lb(-10) ub(35) omit(6)"

local data_schlenker_F = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
local data_month_schlenker_F = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
local bins_schlenker_F = "binsize(10) lb(10) ub(90) omit(6)"

* GHCN yearly averages
/* use "${path}Haru/processed/ghcn_UScountylevel_1968_2016.dta", clear

gen tmean = (TMAX + TMIN) / 2
bysort fips year: egen avg_yearly_temp = mean(tmean)
keep fips year avg_yearly_temp
duplicates drop

tempfile ghcn_ext_avgtemp
save `ghcn_ext_avgtemp' */

* PRISM yearly averages
/* use "${path}Haru/data/PRISM_Schlenker/appended.dta", clear

bysort fips year: egen avg_yearly_temp = mean(tMax)
keep fips year avg_yearly_temp
replace avg_yearly_temp = (avg_yearly_temp * 9 / 5) + 32
duplicates drop

tempfile schlenker_F_avgtemp
save `schlenker_F_avgtemp'  */

/* * ERA 5 yearly averages
use "${path}DTA_US/countyLevel_US_1970_2019.dta", clear
keep latitude longitude fips year month avg_temp_daytime* avg_temp_day*
reshape long avg_temp_daytime avg_temp_day, i(fips year  latitude longitude month) j(day)
drop latitude longitude
drop if avg_temp_daytime == .

bysort fips year: egen avg_yearly_temp = mean(avg_temp_daytime)
keep fips year avg_yearly_temp
replace avg_yearly_temp = (avg_yearly_temp * 9 / 5) + 32
duplicates drop

tempfile era5_F_avgtemp
save `era5_F_avgtemp' */

* ERA 5 yearly averages
use "${path}DTA_US/countyLevel_USPanel_1970_2019.dta", clear
      //this uses ERA Land, not ERA 5

drop if year > 2019 | year < 1970
keep fips year avg_yearly_temp //avg_yearly_temp uses whole day avg not daytime avg
replace avg_yearly_temp = (avg_yearly_temp * 9 / 5) + 32
duplicates drop

tempfile era5_F_avgtemp
save `era5_F_avgtemp'
tempfile era5_F_naive_avgtemp
save `era5_F_naive_avgtemp'
tempfile era5_F_avgtrend_avgtemp
save `era5_F_avgtrend_avgtemp'
tempfile era5_F_avgtrend_bayes_avgtemp
save `era5_F_avgtrend_bayes_avgtemp'
tempfile era5_F_bayes_avgtemp
save `era5_F_bayes_avgtemp'
tempfile era5_F_chebyshev_avgtemp
save `era5_F_chebyshev_avgtemp'
tempfile era5_F_avgtrend_bayes_avgtemp
save `era5_F_avgtrend_bayes_avgtemp'
tempfile era5_F_splines_avgtemp
save `era5_F_splines_avgtemp'

* add state information
preserve
	import delimited "${path}Haru/data/county_centroid.csv", clear
	keep fips state

	tempfile fipsToState
	save `fipsToState', replace
restore

********************************************************************************
** RUN
********************************************************************************
foreach source in era5_F_avgtrend era5_F_avgtrend_bayes era5_F_splines { // era5_F schlenker_F ghcn_ext schlenker_F  era5_F_bayes era5_F_chebyshev era5_F_avgtrend

      * Prepare dataset
      use "`data_`source''", clear

      log using "${path}Haru/log/bindev_`source'.txt", text replace
      display "Current time: " c(current_date) " " c(current_time)

      * Merge average temps
      merge m:1 year fips using ``source'_avgtemp'
      keep if _merge == 3
      drop _merge

      * create pre period temperature
      gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
      bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

      local binsize = 10
      local lb = 10
      local ub = 90

      * add state information
      merge m:1 fips using `fipsToState'
      drop if _merge != 3
      drop _merge
      egen stateCode = group(state)
      drop if state == "AK" | state == "PR" | state == "HI"

      ******************************* Binning
      * Bin for below lower bound
      local lb_str = cond(`lb' < 0, "n`=abs(`lb')'", "`lb'") //to create the string "n#" for negative numbers
      local names_bins = "under_`lb_str'"

      * Loop through the middle bins
      local ub_bin = `ub'-`binsize'
      forvalues start = `lb'(`binsize')`ub_bin' {
            local end = `start' + `binsize'
            local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
            local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")

            local names_bins = "`names_bins' `start_label'_`end_label'"
      }

      * Bin for above upper bound
	local above_str = cond(`ub' < 0, "n`=abs(`ub')'", "`ub'") //to name the bin real_over_`ub'
      local names_bins = "`names_bins' over_`above_str'"

      foreach bin in `names_bins' { //
            
            if strpos("`source'", "naive") > 0 {
                  gen diff_`bin' = real_`bin'
            }
            if strpos("`source'", "naive") <= 0 {
                  gen diff_`bin' = real_`bin' - exp_`bin'
            }

            * Mean
            preserve
            bysort fips: egen avg_diff_`bin' = mean(diff_`bin')
            keep avg_diff_`bin' fips
            duplicates drop
            tab fips if abs(avg_diff_`bin') > 0.01 
            /* list if avg_diff_`bin' < -3 | avg_diff_`bin' > 3 */

            quietly summarize avg_diff_`bin', detail
            local max = r(max) - 0.25
            local mean = string(round(r(mean), 0.001), "%5.3f")
            local median = string(round(r(p50), 0.001), "%5.3f")

            twoway__histogram_gen avg_diff_`bin', gen(hist_density hist_bin)
            quietly summarize hist_density
            local ymean = r(max)
            local ymedian = `ymean' * 0.8

            // Create the histogram with xline at 0 and text for mean and median
            histogram avg_diff_`bin', ///
            xtitle("Mean Deviation in Days from Counterfactual by County") ///
                  xline(0, lpattern(dash) lcolor(red)) ///
                  text(`ymean' `max' "Mean: `mean'", color(black)) ///
                  text(`ymedian' `max' "Median: `median'", color(black)) //xlabel(-5(1)5)
            cap mkdir "${output}bindev/`source'/"
            graph export "${output}bindev/`source'/bindev_mean`bin'_`source'.pdf", replace
            restore

            * Trend
            preserve

            qui levelsof fips, local(fips_code)
            gen coefs = .
            /* local k = 1 */
            foreach fip in `fips_code' {
                  qui regress diff_`bin' year if fips == `fip'
                  qui replace coefs = _b[year] if fips == `fip'
                  /* local k = `k' + 1 */
            }
            keep coefs baselinePeriodTemp
            duplicates drop

            qui sum coefs
            local ymean = r(max)
            local yslope = `ymean' - 0.1
            local mean = string(round(r(mean), 0.001), "%5.3f")

            * Slope of the scatter plot
            qui regress coefs baselinePeriodTemp
            local slope = string(round(_b[baselinePeriodTemp], 0.001), "%5.3f")

            twoway (scatter coefs baselinePeriodTemp) (lfit coefs baselinePeriodTemp), ///
                  xtitle("Baseline Temperature (1970s)") ///
                  ytitle("Trend of Deviation in Days from Counterfactual") ///
                  text(`ymean' 75 "Mean: `mean'", color(black)) ///
                  text(`yslope' 75 "Slope: `slope'", color(black)) legend(off)
            graph export "${output}bindev/`source'/bindev_trend`bin'_`source'.pdf", replace
            restore
      }

      log close

}