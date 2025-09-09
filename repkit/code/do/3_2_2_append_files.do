/*******************************************************************************
AUTHOR: Harufumi Nakazawa
DATE: June 2025
ACTION: 
      Appends files created by parallel_bias_table.do
      Plots the density of sim 2 coefficients and t-stats
*******************************************************************************
Set Up
*********************************/
args data repkit
global data "`data'"
global repkit "`repkit'"

do "${repkit}code/do/0_setup.do"

log using "${log}3_2_analysis/3_2_2_append_files.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Locals
*********************************/
local methods  "naive stateyearFE lag3 trends 5year year bayes chebyshev adapt"
local n_methods  : word count `methods'
local count = `n_methods'-1
/*********************************
Run
*********************************/
local k = 1
foreach binform in allbins extreme {
      foreach source in era5 { // prism_1950 prism_1970 ghcn 

            *** Define output file name and delete it if it already exists to avoid appending multiple times            
            * CSVs
            foreach power in lin quad cubic {
                  local output_csv_`power' "${intermediate}power_table_`power'_`binform'_`source'_bin${binsize}.csv"
                  shell rm -f `output_csv_`power''
            }

            *** Append files together and save the output file
            forvalues i = 1/`count' {
                  local j = `n_methods' * (`k' - 1) + `i'
                  
                  * CSVs
                  foreach power in lin quad cubic {
                        if `i' == 1 {
                              // Include header for the first file
                              shell cat "${temp}cftemp_`source'_bin${binsize}_`power'_`binform'_`j'.csv" >> `output_csv_`power''
                        }
                        else {
                              // Skip header (first line) for all subsequent files
                              shell tail -n +2 "${temp}cftemp_`source'_bin${binsize}_`power'_`binform'_`j'.csv" >> `output_csv_`power''
                        }
                  }
                  /* shell rm -f "${output}/bindev/cftemp_`source'_`power'_`binform'_`j'.csv" */
            }

            * Count sources
            local k = `k' + 1
      }
}

log close