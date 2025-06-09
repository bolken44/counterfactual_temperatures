/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: April 2025
ACTION: Process migration panel data
*******************************************************************************/

use "/Volumes/pbolken/climate/Haru/data/outcomes/migrationout_1990_2022.dta", clear

gen nonmig = (strpos(description, "Non-Mig") > 0 | strpos(description, "Non-mig") > 0 )
gen totmig = strpos(description, "Tot") > 0
gen confirm = nonmig + totmig
list if confirm != 1
replace totmig = 0 if confirm == 2 //checked, 1 obs from co934vao.xls

foreach var in returns exemptions agg_income {
	drop if `var' < 0
	
	gen `var'_nonmig = `var' if nonmig == 1
	replace `var'_nonmig = 0 if nonmig == 0
	replace `var'_nonmig = . if `var' == .
	
	gen `var'_totmig = `var' if totmig == 1
	replace `var'_totmig = 0 if totmig == 0
	replace `var'_totmig = . if `var' == .
	
}

* Drop missings (none dropped)
drop if returns_totmig == . | returns_nonmig == .
drop if exemptions_totmig == . | exemptions_nonmig == .
drop if (agg_income_totmig == . | agg_income_nonmig == .) & year >= 1992


replace origin_state = string(real(origin_state))
replace origin_county = string(real(origin_county), "%03.0f")
gen fips = origin_state + origin_county
order fips year returns_* exemptions_* agg_income_*
drop if origin_county == "000" //these are state aggregates
drop if origin_state == "57"
replace fips = "46102" if fips == "46113" //changed fip codes
replace fips = "12086" if fips == "12025"

keep if year <= 2017

sort fips year
bysort fips year: gen year_tag = _n == 1
bysort fips: egen year_count = total(year_tag)
sum year_count, detail


collapse (sum) returns_* exemptions_* agg_income_* (mean) year_count, by(fips year)

foreach var in returns exemptions agg_income {
	gen `var'_rate = `var'_totmig / (`var'_nonmig + `var'_totmig)
	bysort year: egen mean_`var'_rate = mean(`var'_rate)
	sum mean_`var'_rate, detail
}

foreach var in returns exemptions agg_income {
	sum `var'_totmig, detail
}
sort fips year
sum year_count, detail
drop if year_count == 2 | year_count == 4
unique fips

rename fips fips_str
gen fips = real(fips_str)

save "/Volumes/pbolken/climate/Haru/data/outcomes/migrationout_panel_1990_2017.dta", replace
