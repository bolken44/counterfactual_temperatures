/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: July 2025
ACTION: Prepare PRISM dataset

*******************************************************************************
Run setup file
*********************************/
args data repkit
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"

log using "${log}/1_2_processPRISM/1_2_processPRISM.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
PRISM
*********************************/
* Keep the grid cell that is closest to the county's centroid
import delimited "${data}fips_county.csv", clear 

replace fips = 46113 if fips == 46102

keep fips latitude longitude
rename latitude latcentroid
rename longitude longcentroid

tempfile fipsCentroid
save `fipsCentroid', replace

************************
use "${data}linkGridnumberFIPS.dta", clear

* not all fips show up in Schlenker data, we only work with those who do
merge m:1 fips using `fipsCentroid', keep(match) nogen

* create latitude and longitude variable
gen lon = -125 + mod(gridNumber-1,1405)/24
	label var lon "longitude of grid centroid (decimal degrees)"
gen lat  = 49.9375+1/48 - ceil(gridNumber/1405)/24
	label var lat  "latitude of grid centroid (decimal degrees)"
		
* calculate distance between grids and centroids
geodist lat lon latcentroid longcentroid, gen(dist)

* keep closest grid to each centroid
bysort fips: egen double minDist = min(dist)

* keep if closest gridpoint
keep if dist == minDist

* transform dataset into matrix 
keep fips gridNumber
mkmat fips gridNumber, matrix(closestGrid)
levelsof fips, local(fipsList)
matrix rownames closestGrid = `fipsList'
matrix colnames closestGrid = fips gridNumber

************************
foreach f of local fipsList{
	
	* for each fips we loop through years
	forvalues year = 1950/2019{
		
		* load file
		use "${raw}PRISM_Schlenker/year`year'/fips`f'.dta", clear
		
		* gen fips and year variables
		gen fips = `f'

		* keep if closest gridpoint
		local gridToKeep = closestGrid["`f'","gridNumber"]
		
		keep if gridNumber == `gridToKeep'
		
		* build average between min and max
		egen tMean = rowmean(tMin tMax)
		drop tMin tMax
		rename tMean tMax
		
		* keep relevant variables
		keep dateNum tMax fips
		
		* save yearly file for a given fips
		tempfile base`f'_`year'
		save `base`f'_`year'', replace
		
	}
}

* Append all fips and years
clear
foreach f of local fipsList{
	forvalues year = 1950/2019{
		append using `base`f'_`year''
	}
}

* Prepare
gen year = year(dateNum)
gen month = month(dateNum)

bysort year: egen avgMaxTemp = mean(tMax)
bysort year: egen medianMaxTemp = median(tMax)

save "${intermediate}prism_appended.dta", replace