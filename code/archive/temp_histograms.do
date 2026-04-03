/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: April 2025
ACTION: Histograms of temperatures by bin
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
** ADD WEATHER DATA
********************************************************************************
local data_era5 = "${weather}era5_UScounty_1970_2019_cftemp.dta"
local data_month_era5 = "${weather}era5_monthly_UScounty_1970_2019_cftemp.dta"
local bins_era5 = "binsize(5) lb(-10) ub(35) omit(6)"

local data_era5_F = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"
local bins_era5_F = "binsize(10) lb(10) ub(90) omit(6)"

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
tempfile era5_F_avgtrend_avgtemp
save `era5_F_avgtrend_avgtemp'
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
foreach source in  era5_F_avgtrend era5_F_avgtrend_bayes era5_F_splines { // era5_F schlenker_F ghcn_ext schlenker_F  era5_F_bayes era5_F_chebyshev era5_F_avgtrend

      * Prepare dataset
      use "`data_`source''", clear

      log using "${path}Haru/log/histograms_`source'.txt", text replace
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

      ******************************* Histograms for Boston and Phoenix
      foreach fip in 25025 4013  { //Boston Phoenix

            foreach year in 1970 1990 2015 {

                  preserve
                  keep if fips == `fip'
                  keep if year == `year'
                  
                  drop state* avg* base*
                  reshape long real_ exp_, i(year fips) j(bin) string

                  replace bin = "0_10" if bin == "under_10"
                  replace bin = "90_100" if bin == "over_90"

                  gen bin_start = real(substr(bin, 1, strpos(bin, "_") - 1))
                  replace bin_start = bin_start + 5

                  gen type = "Real"
                  rename real_ value
                  tempfile temp
                  save `temp'
                  
                  replace exp_ = .
                  
                  append using `temp'
                  replace value = exp_ if _n > 10 
                  replace type = "Expected" if _n > 10 
                  drop exp_

                  sort bin_start type

                  twoway ///
                        (bar value bin_start if type == "Real", barwidth(10) color(blue%50)) ///
                        (bar value bin_start if type == "Expected", barwidth(10) color(red%50)), ///
                        legend(order(1 "Real" 2 "Expected")) ///
                        ytitle("Number of Days") ///
                        xtitle("Bin (Starting value)") ///
                        xlabel(0(10)100)

                  cap mkdir "${output}histograms/`source'/"
                  graph export "${output}histograms/`source'/hist_`fip'_`year'_`source'.pdf", replace

                  restore

            }
      }

      log close

}