/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: April 2025
ACTION:
- Runs the regressions for mortality outside of the US
*******************************************************************************/

clear all
set more off

ssc install ppmlhdfe

global path "/proj/pbolken/climate/" //To run from Dropbox, change to the "Temperature and Research" folder
global weather "${path}Haru/processed/"
global outcomes "${path}Haru/data/outcomes/"
global output "${path}Haru/output/"

log using "${path}Haru/log/global_mortality", text replace
display "Current time: " c(current_date) " " c(current_time)

adopath + "${path}/Haru/cftemp"
qui run "${path}/Haru/cftemp/cftemp_plot.ado"

********************************************************************************
** MORTALITY MORTALITY
********************************************************************************

local pre_month = "monthly_"
local group_month = "month year"
local group_year = "year"
local fe_month = "time geo_time1 geo_time2"
local fe_year = "time geo_time1"

* Cohen et al (2022) data
/* foreach level in year month {
      * Temperature data
      use "${weather}cohen_`pre_`level''mexico_1980_2018_cftemp.dta", clear
      unique fips
      keep if year >= 1998 // CVE_ENT CVE_MUN year do not uniquely identify obs unless we do this
      duplicates list CVE_ENT CVE_MUN `group_`level'' //panel was unbalanced
      tempfile temperature
      save `temperature'

      * Rain data
      use "${path}/Haru/data/cohen2022/PRECIPITATION_AEJ.dta", clear
      rename anio year
      rename mes month

      collapse (mean) PREC, by(CVE_ENT CVE_MUN `group_`level'')

      tempfile rain
      save `rain'

      * Outcome data
      use "${outcomes}DEATH_1998_2017_AEJ.dta", clear

      rename anio year
      rename mes month

      gen deaths_all = death_rate_A0_OCUR * pop_total
      gen deaths_more65 = death_rate_K0_OCUR * (pop_65_69 + pop_70_74) + death_rate_L0_OCUR * pop_75p
      gen pop_more65 = pop_65_69 + pop_70_74 + pop_75p

      collapse (sum) deaths_all deaths_more65 (mean) pop_total pop_more65, by(CVE_ENT CVE_MUN `group_`level'')
      gen mortality_all = deaths_all / pop_total * 100000 //deaths per 100,000 inhabitants
      gen mortality_more65 = deaths_more65 / pop_more65 * 100000

      merge 1:1 CVE_ENT CVE_MUN `group_`level'' using `temperature'
      keep if _merge == 3
      drop _merge

      merge 1:1 CVE_ENT CVE_MUN `group_`level'' using `rain'
      keep if _merge == 3
      drop _merge

      egen time = group(`group_`level'')
      egen geo_time1 = group(fips `level')
      egen geo_time2 = group(fips year)

      foreach outcome in all more65 {
            cftemp_plot mortality_`outcome', binsize(4) lb(12) ub(32) aweights(`pop_all') control(PREC) fe(fips time) cluster(fips)
            graph export "${output}cohen/mortality_`outcome'_`level'.jpg", replace
      }
} */


* ERA 5 (C) and Cohen et al binning
/* foreach level in year month {
      * Temperature data
      use "${weather}era5_`pre_`level''MEXcounty_1970_2019_cftemp.dta", clear
      unique fips
      keep if year >= 1998 // CVE_ENT CVE_MUN year do not uniquely identify obs unless we do this
      duplicates list CVE_ENT CVE_MUN `group_`level'' //panel was unbalanced
      tempfile temperature
      save `temperature'

      * Rain data
      use "${path}/Haru/data/cohen2022/PRECIPITATION_AEJ.dta", clear
      rename anio year
      rename mes month

      collapse (mean) PREC, by(CVE_ENT CVE_MUN `group_`level'')
      tostring CVE_ENT CVE_MUN, replace force format(%02.0f)

      tempfile rain
      save `rain'

      * Outcome data
      use "${outcomes}DEATH_1998_2017_AEJ.dta", clear

      rename anio year
      rename mes month

      gen deaths_all = death_rate_A0_OCUR * pop_total
      gen deaths_more65 = death_rate_K0_OCUR * (pop_65_69 + pop_70_74) + death_rate_L0_OCUR * pop_75p
      gen pop_more65 = pop_65_69 + pop_70_74 + pop_75p

      collapse (sum) deaths_all deaths_more65 (mean) pop_total pop_more65, by(CVE_ENT CVE_MUN `group_`level'')
      gen mortality_all = deaths_all / pop_total * 100000 //deaths per 100,000 inhabitants
      gen mortality_more65 = deaths_more65 / pop_more65 * 100000

      tostring CVE_ENT CVE_MUN, replace force format(%02.0f)
      merge 1:1 CVE_ENT CVE_MUN `group_`level'' using `temperature'
      keep if _merge == 3
      drop _merge

      merge 1:1 CVE_ENT CVE_MUN `group_`level'' using `rain'
      keep if _merge == 3
      drop _merge

      egen time = group(`group_`level'')
      egen geo_time1 = group(fips `level')
      egen geo_time2 = group(fips year)

      foreach outcome in all more65 {
            cftemp_plot mortality_`outcome', binsize(4) lb(12) ub(32) aweights(`pop_all') control(PREC) fe(fips time) cluster(fips)
            graph export "${output}cohen/mortality_`outcome'_`level'_era5.jpg", replace
      }
}
exit */

* ERA 5 (F)
/* use "${path}/Haru/data/cohen2022/countyLevel_MEX_1970_2019.dta", clear
egen fips = group(CVE_ENT CVE_MUN)
keep fips CVE_ENT CVE_MUN
duplicates drop
tempfile mexfips
save `mexfips' */

foreach level in month { //month 
      * Temperature data
      use "${weather}era5_`pre_`level''MEXcounty_1970_2019_cftemp_F_50.dta", clear
      unique fips
      keep if year >= 1998 // CVE_ENT CVE_MUN year do not uniquely identify obs unless we do this
      /* merge m:1 fips using `mexfips'
      drop _merge */

      duplicates list CVE_ENT CVE_MUN `group_`level'' //panel was unbalanced
      tempfile temperature
      save `temperature'

      * Rain data
      use "${path}/Haru/data/cohen2022/PRECIPITATION_AEJ.dta", clear
      rename anio year
      rename mes month

      collapse (mean) PREC, by(CVE_ENT CVE_MUN `group_`level'')
      tostring CVE_ENT CVE_MUN, replace force format(%02.0f)

      tempfile rain
      save `rain'

      * Outcome data
      use "${outcomes}DEATH_1998_2017_AEJ.dta", clear

      rename anio year
      rename mes month

      gen deaths_all = death_rate_A0_OCUR * pop_total
      gen deaths_more65 = death_rate_K0_OCUR * (pop_65_69 + pop_70_74) + death_rate_L0_OCUR * pop_75p
      gen pop_more65 = pop_65_69 + pop_70_74 + pop_75p

      collapse (sum) deaths_all deaths_more65 (mean) pop_total pop_more65, by(CVE_ENT CVE_MUN `group_`level'')
      gen mortality_all = deaths_all / pop_total * 100000 //deaths per 100,000 inhabitants
      gen mortality_more65 = deaths_more65 / pop_more65 * 100000

      tostring CVE_ENT CVE_MUN, replace force format(%02.0f)
      merge 1:1 CVE_ENT CVE_MUN `group_`level'' using `temperature'
      keep if _merge == 3
      drop _merge

      merge 1:1 CVE_ENT CVE_MUN `group_`level'' using `rain'
      keep if _merge == 3
      drop _merge

      egen time = group(`group_`level'')
      egen geo_time1 = group(fips `level')
      egen geo_time2 = group(fips year)

      ds real_under_*
      local varname `r(varlist)'
      local lb : subinstr local varname "real_under_" "", all

      ds real_over_*
      local varname `r(varlist)'
      local ub : subinstr local varname "real_over_" "", all

      local binsize = (`ub' - `lb') / 8

      foreach outcome in all more65 {
            cftemp_plot mortality_`outcome', binsize(`binsize') lb(`lb') ub(`ub') omit(6) control(PREC) fe(fips time) cluster(fips)
            graph export "${output}cohen/mortality_`outcome'_`level'_era5_F_50.jpg", replace
      }
}


********************************************************************************
** INDIA MORTALITY
********************************************************************************

* ERA 5 (F)
foreach level in year {
      * Temperature data
      use "${weather}era5_`pre_`level''INDcounty_1970_2019_cftemp_F_10.dta", clear
      unique fips
      keep if year <= 2001

      duplicates list state district `group_`level'' //panel was unbalanced
      tempfile temperature
      save `temperature'

      * Climatic regions
      use "${outcomes}climate_regions_combined.dta", clear
      duplicates drop
      tempfile climatic
      save `climatic'

      * Outcome data
      use "${outcomes}IND_cleaned_merged.dta", clear
      /* use "${outcomes}IND_infant_mortality.dta", clear */
      ds
      keep if year >= 1970
      egen geo = group(state district)
      xtset year geo

      merge 1:1 year state district using `temperature'
      keep if _merge == 3
      drop _merge

      * Merge climatic regions
      merge m:1 state using `climatic'
      gen yearsq = year * year

      * Extract bin structure
      ds real_under_*
      local varname `r(varlist)'
      local lb : subinstr local varname "real_under_" "", all

      ds real_over_*
      local varname `r(varlist)'
      local ub : subinstr local varname "real_over_" "", all

      local binsize = 10 //(`ub' - `lb') / 8

      * Log deathrate
      foreach outcome in deathrate infdeathrate { //
            gen log_`outcome' = log(`outcome')
      }

      * Winsorize deathrate
      foreach outcome in deathrate infdeathrate { //
            egen `outcome'_p99 = pctile(`outcome'), p(99)
            gen `outcome'_w99 = `outcome'
            replace `outcome'_w99 = `outcome'_p99 if `outcome' > `outcome'_p99 & !mi(`outcome')
            drop `outcome'_p99
      }

	* Set weight
	bysort year: egen tot_pop = total(population)
	gen weight = population / tot_pop

      foreach outcome in deathrate deathrate_w99 infdeathrate infdeathrate_w99 log_deathrate log_infdeathrate { //
            * Simple
            cftemp_plot `outcome', binsize(`binsize') lb(`lb') ub(`ub') omit(5) fe(fips year) cluster(fips)
            graph export "${output}india/mortality_`outcome'_`level'_era5_F_10.jpg", replace

            * Weighted
            cftemp_plot `outcome', binsize(`binsize') lb(`lb') ub(`ub') omit(5) aweights(weight) fe(fips year) cluster(fips)
            graph export "${output}india/mortality_`outcome'_`level'_era5_F_10_w.jpg", replace

            * Climatic region linear trends
            cftemp_plot `outcome', binsize(`binsize') lb(`lb') ub(`ub') omit(5) fe(fips year) cluster(fips) control(region#c.year)
            graph export "${output}india/mortality_`outcome'_`level'_era5_F_10_lin.jpg", replace

            * Climatic region linear and quadratic trends
            cftemp_plot `outcome', binsize(`binsize') lb(`lb') ub(`ub') omit(5) fe(fips year) cluster(fips) control(region#c.year region#c.yearsq)
            graph export "${output}india/mortality_`outcome'_`level'_era5_F_10_quad.jpg", replace
      }
}