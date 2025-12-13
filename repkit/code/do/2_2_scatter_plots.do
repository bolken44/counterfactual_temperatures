/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: May 2025
ACTION: Creates scatter plots
*******************************************************************************
Set Up
*********************************/
args data repkit
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"
/* global pool "/orcd/pool/003/hnaka24/climate/"
global weather "${pool}processed/" */

log using "${log}2_2_scatter_plots/2_2_scatter_plots.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Locals
*********************************/
local base_era5 = 1980
local base_prism_1950 = 1960
local base_prism_1970 = 1980
local base_ghcn = 1980

* Sample period start year
local minyear_ghcn = 1968
local minyear_era5_F = 1970

local omit = 55 // for polynomials

* Theoretical Bias values (hardcoded)
local biasUnder${lb_str}Group0 = 0.72  // Specify bias for below median, under 10
local biasUnder${lb_str}Group1 = 28.6  // Specify bias for above median, under 10
local biasOver${ub_str}Group0 = 6.42   // Specify bias for below median, over 90
local biasOver${ub_str}Group1 = 1.60   // Specify bias for above median, over 90

global source = "`source'"
global method = "`method'"

* average temperature (delete later)
/* use "${weather}countyannual_US_1970_2019.dta", clear
/* use "${weather}countyLevel_USPanel_1970_2019_v2.dta", clear  // this is what Cristine used originally
replace avg_yearly_temp = (avg_yearly_temp * 9/5) + 32 */
tempfile `source'_avgtemp
save ``source'_avgtemp', replace */

/*********************************
Prepare Dataset
*********************************/
use "${temperature}`source'_UScounty_cftemp_F_bin10_year.dta", clear
/* use "${weather}era5_UScounty_1970_2019_cftemp_F.dta", clear */

xtset fips year
drop if year > 2019 | year < 1970

* Merge average temps
/* merge m:1 year fips using ``source'_avgtemp'
assert _merge == 3
drop _merge */

* add state information
merge m:1 fips using "${data}UScounty_state_crosswalk.dta"
egen stateCode = group(state)
drop if state == "AK" | state == "PR" | state == "HI"
drop _merge

* create pre period temperature
gen baselinePeriodTemp = avg_yearly_temp if year <= 1980
bysort fips: ereplace baselinePeriodTemp = mean(baselinePeriodTemp)

* create numeric variable for year
xtset fips year

* generate variables to fill
gen varName = ""
gen loop = .
gen coef = .
gen sE = .
gen varNum = .
gen pValue = .

* Save temperature std deviation
gen temp = year * baselinePeriodTemp
sum temp

local halfStdDevValue 		= `r(sd)'/2
local oneStdDevValue 		= `r(sd)'
local twoStdDevValue	 	= `r(sd)'*2
local fourStdDevValue	 	= `r(sd)'*4

drop temp

* gen tag to plot one observation per county
egen tag = tag(fips)

sum baselinePeriodTemp, detail
local medianPreTemp = `r(p50)'
gen aboveMedian = baselinePeriodTemp > `medianPreTemp'

/*********************************
Whole Sample
*********************************/
* generate decade variable
gen decade = year/10
replace decade = floor(decade)

preserve

* collapse
collapse (sum) real_* (mean) baselinePeriodTemp, by(fips decade)

* difference in days above 90F
gen real_over_${ub_str}_1970 = real_over_${ub_str} if decade == 197
	bysort fips: ereplace real_over_${ub_str}_1970 = mean(real_over_${ub_str}_1970)
gen real_over_${ub_str}_2010 = real_over_${ub_str} if decade == 201
	bysort fips: ereplace real_over_${ub_str}_2010 = mean(real_over_${ub_str}_2010)
gen diff_real_over_${ub_str} = real_over_${ub_str}_2010 - real_over_${ub_str}_1970

* difference in days below 0
gen real_under_${lb_str}_1970 = real_under_${lb_str} if decade == 197
	bysort fips: ereplace real_under_${lb_str}_1970 = mean(real_under_${lb_str}_1970)
gen real_under_${lb_str}_2010 = real_under_${lb_str} if decade == 201
	bysort fips: ereplace real_under_${lb_str}_2010 = mean(real_under_${lb_str}_2010)
gen diff_real_under_${lb_str} = real_under_${lb_str}_2010 - real_under_${lb_str}_1970

* gen baseline temperature
gen baselineTemp = baselinePeriodTemp if decade == 197
	bysort fips: ereplace baselineTemp = mean(baselineTemp)
	
* identify counties where Boston and Phoenix are
gen boston_real_under_${lb_str} 	= diff_real_under_${lb_str} 	if fips == 25025
gen boston_real_over_${ub_str} 	= diff_real_over_${ub_str} 	if fips == 25025
gen boston_temp 			      = baselineTemp 			if fips == 25025 
gen boston_lab 				= "Boston" 				if fips == 25025 

gen phoenix_real_under_${lb_str} 	= diff_real_under_${lb_str}	if fips == 4013
gen phoenix_real_over_${ub_str} 	= diff_real_over_${ub_str} 	if fips == 4013
gen phoenix_temp 			      = baselineTemp 			if fips == 4013 
gen phoenix_lab 			      = "Phoenix" 

** tab number of days in each temperature bin for Boston and Phoenix
* Boston under 10F
tab real_under_${lb_str} if fips == 25025 & decade == 197
tab real_under_${lb_str} if fips == 25025 & decade == 201

* Phoenix under 10F
tab real_under_${lb_str} if fips == 4013 & decade == 197
tab real_under_${lb_str} if fips == 4013 & decade == 201

* Boston over 90F
tab real_over_${ub_str} if fips == 25025 & decade == 197
tab real_over_${ub_str} if fips == 25025 & decade == 201

* Phoenix over 90F
tab real_over_${ub_str} if fips == 4013 & decade == 197
tab real_over_${ub_str} if fips == 4013 & decade == 201

* plots
/* twoway (scatter diff_real_over_${ub_str}  baselineTemp if decade == 197, mcolor(maroon)) ///
	(scatter diff_real_under_${lb_str}  baselineTemp if decade == 197, mcolor(navy)), ///
	xtitle("Baseline temperature (1970s)") ytitle("Change in days (2010s - 1970s)") legend(order(1 "Days over 90°F" 2 "Days under 10°F"))
	graph export "Writing/PresentationFigures/diff_Under${lb_str}_Over${ub_str}_part1_F.pdf", replace */
	
twoway (scatter diff_real_over_${ub_str}  baselineTemp if decade == 197, color(maroon%30)) (scatter diff_real_under_${lb_str}  baselineTemp if decade == 197, color(navy%30)) ///
	(scatter boston_real_over_${ub_str} boston_temp if decade == 197, mcolor(maroon) mlcolor(black) msize(large) mlabel(boston_lab) mlabposition(12) mlabcolor(black)) ///
	(scatter boston_real_under_${lb_str} boston_temp if decade == 197, mcolor(navy) mlcolor(black) msize(large) mlabel(boston_lab) mlabposition(6) mlabcolor(black))  ///
	(scatter phoenix_real_over_${ub_str} phoenix_temp if decade == 197, mcolor(maroon) mlcolor(black) msize(large) mlabel(phoenix_lab) mlabposition(12) mlabcolor(black)) ///
	(scatter phoenix_real_under_${lb_str} phoenix_temp if decade == 197, mcolor(navy) mlcolor(black) msize(large) mlabel(phoenix_lab) mlabposition(6) mlabcolor(black)) ///
	, xtitle("Baseline temperature (1970s)") ytitle("Change in days (2010s - 1970s)") legend(order(3 "Days over 90°F" 4 "Days under 10°F") pos(6) row(1) region(lcolor(none))) yline(0) xlabel(, nogrid) ylabel(, nogrid) graphregion(color(white))
	graph export "${figures}scatter/diff_Under${lb_str}_Over${ub_str}_F.pdf", replace

restore

/*********************************
Adaptation
*********************************/
** temperature bin trends: 
foreach var in real_under_$lb_str real_over_$ub_str {
	
	foreach g in 0 1 {

		gen alphaCoefficientSlope1 = .
		
		************************* temperature bins by groups
		* reghdfe `var' if aboveMedian == `g', absorb(fips year alphaCoefficient = i.fips#c.year)
		* assign alpha coefficient to all 
		* replace alphaCoefficientSlope1 = alphaCoefficientSlope1 + _cons
		
		levelsof fips, local(fips)
		foreach f of local fips{
			reg `var' year if fips == `f'
			replace alphaCoefficientSlope1 = _b[year] if fips == `f'
		} 
		
		*rename alphaCoefficientSlope1 alpha`var'Group`g'
		*bysort fips: ereplace alpha`var'Group`g' = mean(alpha`var'Group`g')	if aboveMedian == `g'
			
		gen alpha`var'Group`g' = alphaCoefficientSlope1 if aboveMedian == `g'	
		drop alphaCoefficientSlope1
	}
}

* extract variance of the trends
sum alphareal_under_${lb_str}Group0
local varUnder${lb_str}Group0: di %7.4f `r(Var)'
sum alphareal_under_${lb_str}Group1
local varUnder${lb_str}Group1: di %7.4f `r(Var)'
sum alphareal_over_${ub_str}Group0
local varOver${ub_str}Group0: di %7.4f `r(Var)'
sum alphareal_over_${ub_str}Group1
local varOver${ub_str}Group1: di %7.4f `r(Var)'

* extract slope of the trends
reg alphareal_under_${lb_str}Group0 baselinePeriodTemp if aboveMedian == 0 
local slopeUnder${lb_str}Group0: di %7.4f _b[baselinePeriodTemp]
reg alphareal_under_${lb_str}Group1 baselinePeriodTemp if aboveMedian == 1
local slopeUnder${lb_str}Group1: di %7.4f _b[baselinePeriodTemp]
reg alphareal_over_${ub_str}Group0 baselinePeriodTemp if aboveMedian == 0 
local slopeOver${ub_str}Group0: di %7.4f _b[baselinePeriodTemp]
reg alphareal_over_${ub_str}Group1 baselinePeriodTemp if aboveMedian == 1
local slopeOver${ub_str}Group1: di %7.4f _b[baselinePeriodTemp]

* Format bias values for display (ensures leading zeros)
local biasUnder${lb_str}Group0_fmt: di %5.2f `biasUnder${lb_str}Group0'
local biasUnder${lb_str}Group1_fmt: di %5.2f `biasUnder${lb_str}Group1'
local biasOver${ub_str}Group0_fmt: di %5.2f `biasOver${ub_str}Group0'
local biasOver${ub_str}Group1_fmt: di %5.2f `biasOver${ub_str}Group1'

* under 10
twoway (scatter alphareal_under_${lb_str}Group0 baselinePeriodTemp if tag == 1, color(%20) mcolor("31 88 137")) (lfit alphareal_under_${lb_str}Group0 baselinePeriodTemp if tag == 1, lwidth(thick) lcolor(dkorange)) ///
      (scatter alphareal_under_${lb_str}Group1 baselinePeriodTemp if tag == 1, color(%20) mcolor("155 52 58")) (lfit alphareal_under_${lb_str}Group1 baselinePeriodTemp if tag == 1, lwidth(thick) lcolor(dkorange)), ///
      legend(order(1 "Below median" 3 "Above median") pos(6) row(1) region(lcolor(none))) ytitle("County specific trend") xtitle("Baseline temperature") xline(`medianPreTemp', lpattern(dash)) ///
      text(-.30 40 "Var =`varUnder${lb_str}Group0', Slope =`slopeUnder${lb_str}Group0'") text(-.30 67.5 "Var =`varUnder${lb_str}Group1', Slope =`slopeUnder${lb_str}Group1'") ///
      text(-.33 40 "Theoretical Bias: `biasUnder${lb_str}Group0_fmt'") text(-.33 67.5 "Theoretical Bias: `biasUnder${lb_str}Group1_fmt'") xlabel(, nogrid) ylabel(, nogrid) graphregion(color(white))
      *text(-.28 40 "Var =`varUnder${lb_str}Group0', Slope =`slopeUnder${lb_str}Group0'") text(-.28 67.5 "Var =`varUnder${lb_str}Group1', Slope =`slopeUnder${lb_str}Group1'")
graph export "${figures}scatter/adaptation_under_${lb_str}_Trend_F_aboveBelowMedian.pdf", replace

* over 90
twoway (scatter alphareal_over_${ub_str}Group0 baselinePeriodTemp if tag == 1, color(%20) mcolor("31 88 137")) (lfit alphareal_over_${ub_str}Group0 baselinePeriodTemp if tag == 1, lwidth(thick) lcolor(dkorange)) ///
      (scatter alphareal_over_${ub_str}Group1 baselinePeriodTemp if tag == 1, color(%20) mcolor("155 52 58")) (lfit alphareal_over_${ub_str}Group1 baselinePeriodTemp if tag == 1, lwidth(thick) lcolor(dkorange)), ///
      legend(order(1 "Below median" 3 "Above median") pos(6) row(1) region(lcolor(none))) ytitle("County specific trend") xtitle("Baseline temperature") xline(`medianPreTemp', lpattern(dash)) ///
      text(.9 40 "Var =`varOver${ub_str}Group0', Slope =`slopeOver${ub_str}Group0'") text(.9 67.5 "Var =`varOver${ub_str}Group1', Slope =`slopeOver${ub_str}Group1'") ///
      text(.83 40 "Theoretical Bias: `biasOver${ub_str}Group0_fmt'") text(.83 67.5 "Theoretical Bias: `biasOver${ub_str}Group1_fmt'") xlabel(, nogrid) ylabel(, nogrid) graphregion(color(white))
      *text(-.45 40 "Var =`varOver${ub_str}Group0', Slope =`slopeOver${ub_str}Group0'") text(-.45 67.5 "Var =`varOver${ub_str}Group1', Slope =`slopeOver${ub_str}Group1'")
graph export "${figures}scatter/adaptation_over_${ub_str}_Trend_F_aboveBelowMedian.pdf", replace