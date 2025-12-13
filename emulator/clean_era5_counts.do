global path = "/Volumes/pbolken/climate/"
global emulator = "${path}emulator/"

local years "1950 1960 1970 1980 1990 2000 2010 2020"

************************************
* Rebin to binsize=5
************************************
local head_era5 = "real"
local head_emu = "exp"

foreach ver in era5 emu {
	foreach year in `years' {
		import delimited "${emulator}`ver'_counts_`year'.csv", varnames(1) clear
		
		* Fips
		gen fips = statefp * 1000 + countyfp, after(countyfp)

		* Setup
		local lb = -20
		local binsize = 1
		local ub = 45
		local vstart = 5
		
		local lb2 = -10
		local binsize2 = 5
		local ub2 = 35
		
		* Under bin
		local i = `vstart'
		local j = `i' + (`lb2' - `lb')

		local lb2_str = cond(`lb2' < 0, "n`=abs(`lb2')'", "`lb2'")
		egen `head_`ver''_under_`lb2_str' = rowtotal(v`i'-v`j')
		dis "`j'"
		
		* Middle bins
		local ub_bin = `ub2'-`binsize2'
		forvalues start = `lb2'(`binsize2')`ub_bin' {
			local end = `start' + `binsize2'
			local start_label = cond(`start' < 0, "n`=abs(`start')'", "`start'")
			local end_label = cond(`end' <= 0, "n`=abs(`end')'", "`end'")
			
			local i = `j' + 1
			local j = `i' + `binsize2' - 1
			
			egen `head_`ver''_`start_label'_`end_label' = rowtotal(v`i'-v`j')
			dis "`j'"
		}

		* Over bin
		local i = `j' + 1
		local j = abs(`lb') + `ub' + `vstart' + 1
		dis "`j'"
		
		local ub2_str = cond(`ub2' < 0, "n`=abs(`ub2')'", "`ub2'")
		egen `head_`ver''_over_`ub2_str' = rowtotal(v`i'-v`j')
		
		* Drop the old bins
		drop v*

		* Sanity check
		egen total = rowtotal(`head_`ver''_*)
		sum total, detail
		drop total
		
		* Save as tempfile
		gen year = `year'
		
		tempfile `ver'_`year'
		save ``ver'_`year'', replace
	}
}

************************************
* Append
************************************
foreach ver in era5 emu {
	clear
	
	foreach year in `years' {
		append using ``ver'_`year''
	}
	tempfile `ver'_all
	save ``ver'_all', replace
}

clear
use `era5_all', replace
merge 1:1 fips year using `emu_all'

sort fips year
order fips year name real_* 

save  "${emulator}era5_counts_all.dta", replace
exit

************************************
* Look at correlation with our attempt
************************************
use "${emulator}era5_counts_all.dta", clear
gen emulator = "emulator"

append using "${path}/Haru/avg_temp_day_cftemp.dta"
// append using "${path}Haru/processed/era5_UScounty_1970_2019_cftemp.dta"
replace emulator = "cftemp" if emulator == ""

drop name statefp countyfp geoid
sort fips year emulator
order fips year emulator


keep if year == 2000
egen totaldays = rowtotal(real_*)
