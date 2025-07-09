/**********************************************************************/
/*
   Author: Harufumi Nakazawa
   Created: July 2025
   Description: Runs all do-files for the paper "With or Without U?"

   This code is set up to run on a high-computing cluster using SLURM.
*/
/**********************************************************************/

/*********************************
Run setup file
*********************************/
do "${do}0_setup.do"

/*********************************
Temperature datasets
*********************************/
local bins = "binsize(5) lb(-10) ub(35) omit(6)"

foreach source in era5 prism_1950 prism_1970 ghcn {
   foreach method in year bayes chebyshev {
      local data_`source'_`method' = "${temperature}`source'_UScounty_cftemp_F_`method'"
   }
}

local data_era5_F_year = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F_year = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"
local bins_era5_F = "binsize(10) lb(10) ub(90) omit(6)"

local data_era5_F_5year = "${weather}era5_UScounty_1970_2019_cftemp_F.dta"
local data_month_era5_F_5year = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F.dta"

local data_era5_F_bayes = "${weather}era5_UScounty_1970_2019_cftemp_F_bayes.dta"
local data_month_era5_F_bayes = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_bayes.dta"

local data_era5_F_chebyshev = "${weather}era5_UScounty_1970_2019_cftemp_F_chebyshev.dta"
local data_month_era5_F_chebyshev = "${weather}era5_monthly_UScounty_1970_2019_cftemp_F_chebyshev.dta"


local data_ghcn = "${weather}ghcn_UScounty_1968_2002_cftemp.dta"
local data_month_ghcn = "${weather}ghcn_monthly_UScounty_1968_2002_cftemp.dta"
local bins_ghcn = "binsize(10) lb(10) ub(90) omit(6)"

local data_ghcn_ext = "${weather}ghcn_UScounty_1968_2016_cftemp.dta"
local data_month_ghcn_ext = "${weather}ghcn_monthly_UScounty_1968_2016_cftemp.dta"
local bins_ghcn_ext = "binsize(10) lb(10) ub(90) omit(6)"

local data_schlenker_F = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
local data_month_schlenker_F = "${weather}schlenker_UScounty_1950_2019_cftemp_F.dta"
local bins_schlenker_F = "binsize(10) lb(10) ub(90) omit(6)"

/*********************************
Run Scripts
*********************************/
* Simulations
do "${do}3_1_simulations.do"

* Real World Applications
do "${do}3_2_real_outcomes.do"