/**********************************************************************/
/*
   Author: Harufumi Nakazawa
   Created: July 2025
   Description: Sets up all do-files for the paper "With or Without U?"

   This code is called from inside each do file.
*/
/**********************************************************************/

clear
set more off
set scheme s2color

/*********************************
Set Seed
*********************************/
set seed 1642

/*********************************
Declare bin structure
*********************************/
global binsize = 10
global lb = 10
global ub = 90
global omit = 6
global bins = "binsize($binsize) lb($lb) ub($ub) omit($omit)"

* Bin for below lower bound
global lb_str = cond($lb < 0, "n`=abs($lb)'", "$lb") //to create the string "n#" for negative numbers
local names_bins = "under_${lb_str}"

* Loop through the middle bins
local ub_bin = $ub-$binsize
forvalues start = $lb($binsize)`ub_bin' {
      local end = `start' + $binsize
      local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
      local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")

      local names_bins = "`names_bins' `start_label'_`end_label'"
}

* Bin for above upper bound
global ub_str = cond($ub < 0, "n`=abs($ub)'", "$ub") //to name the bin real_over_$ub
local names_bins = "`names_bins' over_${ub_str}"

/*********************************
Set Switches
*********************************/
* Install package switch
global install_packages = 0

/*********************************
Set Filepaths
*********************************/
global code "${repkit}code/"
global output "${repkit}output/"
global log "${repkit}log/"

* Data folders
global raw "${data}raw/"
global temp "${data}temp/"
global intermediate "${data}intermediate/"
global temperature "${data}temperature/"
global outcomes "${data}outcomes/"

* Code folders
global ado "${code}ado/"
global do "${code}do/"

* Output folders
global figures "${output}figures/"
cap mkdir "${output}figures/"
global tables "${output}tables/"
cap mkdir "${output}tables/"

global simulations "${output}figures/simulations_1SD/"
cap mkdir "$simulations"
cap mkdir "${simulations}sim1/"
cap mkdir "${simulations}sim2/"
cap mkdir "${simulations}sim3/"
global density "${output}figures/density_1SD/"
cap mkdir "$density"
cap mkdir "${density}allbins"
cap mkdir "${density}extreme"

cap mkdir "${figures}real_outcomes/"
cap mkdir "${figures}scatter/"

/*********************************
Install Required Packages
*********************************/
if $install_packages == 1 {
      ssc install ftools, replace
      ssc install gtools, replace
      ssc install reghdfe, replace
      ssc install parallel, replace
      ssc install ereplace, replace
      ssc install geodist, replace
      ssc install geonear, replace
}

/*********************************
Run ado files
*********************************/
adopath + "${ado}"
run "${ado}cftemp.ado"
run "${ado}cftemp_sim.ado"
run "${ado}cftemp_plot.ado"

/*********************************
Add State Information
*********************************/
import delimited "${data}county_centroid.csv", clear
keep fips state

save "${data}UScounty_state_crosswalk.dta", replace
