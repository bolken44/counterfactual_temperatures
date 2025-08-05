/**********************************************************************/
/*
   Author: Harufumi Nakazawa
   Created: July 2025
   Description: Sets up all do-files for the paper "With or Without U?"

   This code is called from inside each do file.
*/
/**********************************************************************/

clear all
set more off
macro drop _all

/*********************************
Set Seed
*********************************/
set seed 1642

/*********************************
Declare bin structure
*********************************/
local binsize = 10
local lb = 10
local ub = 90
local omit = 6
global bins = "binsize(`binsize') lb(`lb') ub(`ub') omit(`omit')"

* Bin for below lower bound
global lb_str = cond(`lb' < 0, "n`=abs(`lb')'", "`lb'") //to create the string "n#" for negative numbers
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
global ub_str = cond(`ub' < 0, "n`=abs(`ub')'", "`ub'") //to name the bin real_over_`ub'
local names_bins = "`names_bins' over_`ub_str'"

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
global temperature "${data}temperature/"
global outcomes "${data}outcomes/"

* Code folders
global ado "${code}ado/"
global do "${code}do/"

* Output folders
global intermediate 
global density "$output/figures/density"

/*********************************
Install Required Packages
*********************************/
if $install_packages == 1 {
      ssc install ftools
      ssc install gtools
      ssc install reghdfe
      ssc install parallel
      ssc install ereplace
      ssc install geodist
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
