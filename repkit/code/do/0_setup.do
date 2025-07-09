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
 Set Switches
*********************************/
* Install package switch
global install_packages = 0

/*********************************
Set Filepaths
*********************************/

/* global root "/proj/pbolken/climate/" */
global repkit "${root}repkit/"
global data "${repkit}data/"
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

/*********************************
Make Directories
*********************************/
cap mkdir $temperature
cap mkdir $output
cap mkdir $output/tables
cap mkdir $output/figures
cap mkdir $output/tables/descriptive
cap mkdir $output/tables/descriptive/sterfiles
cap mkdir $output/tables/descriptive/tex
cap mkdir $output/tables/impacts
cap mkdir $output/tables/impacts/sterfiles
cap mkdir $output/tables/impacts/tex
cap mkdir $output/tables/impacts/csv
cap mkdir $output/figures/descriptive
cap mkdir $output/figures/descriptive/pdf
cap mkdir $output/figures/descriptive/png
cap mkdir $log

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