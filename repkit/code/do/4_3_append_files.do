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

log using "${log}4_3_append_files/4_3_append_files.txt", text replace
display "Current time: " c(current_date) " " c(current_time)

/*********************************
Locals
*********************************/
local title_era5 = "ERA 5 (1970-2019)"
local title_prism_1950 = "PRISM (1950-2019)"
local title_prism_1970 = "PRISM (1970-2019)"
local title_ghcn = "GHCN (1970-2016)"

local sample_era5_F = "The sample period is 1970-2019 for ERA Land 5."
local sample_schlenker_F = "The sample period is 1950-2019 for this version of PRISM."
local sample_prism_1970 = "The sample period is 1970-2019 for this version of PRISM."
local sample_ghcn_ext = "The sample period is 1970-2016 for GHCN."

/*********************************
Run
*********************************/
local k = 1
foreach source in era5 prism_1950 prism_1970 ghcn {

      *** Define output file name and delete it if it already exists to avoid appending multiple times
      * TEXs
      foreach table in bias_table power_table {
            local `table'_tex "${intermediate}`table'_`source'.tex"
            shell rm -f ``table'_tex'
      }
      
      * CSVs
      foreach power in linear quadratic cubic {
            local output_csv "${intermediate}power_table_`power'_`source'.csv"
            shell rm -f `output_csv'
      }

      *** Append files _1.tex to _12.tex into the output file
      forvalues i = 1/12 {
            local j = 12 * (`k' - 1) + `i'
            
            * TEXs
            foreach table in bias_table power_table {
                  foreach bin in under_10 over_90 {
                        local `source'_`table'_`bin' = ""

                        file open in using "${intermediate}`table'_`source'_`j'_`bin'.tex", read text
                        file read in line
                        
                        while (r(eof)==0) {
                              local `source'_`table'_`bin'  "``source'_`table'_`bin'' `line'"
                              file read in line
                        }

                        file close in
                  }
            }
            
            * CSVs
            foreach power in linear quadratic cubic {
                  if `i' == 1 {
                        // Include header for the first file
                        shell cat "${intermediate}cftemp_`source'_`power'_`j'.csv" >> `output_csv'
                  }
                  else {
                        // Skip header (first line) for all subsequent files
                        shell tail -n +2 "${intermediate}cftemp_`source'_`power'_`j'.csv" >> `output_csv'
                  }
            }
            shell rm -f "${output}/bindev/cftemp_`source'_`power'_`j'.csv"
      }

      *** Write the output tex
      * Bias Table
      file open bias_table_`source' using "`bias_table_tex'", write replace
      file write bias_table_`source' ///
            "\clearpage" _n ///
            "\thispagestyle{empty}" _n ///
            "\newgeometry{top=1in, bottom=1in, left=0.3in, right=0.3in}" _n ///
            "\begin{landscape}" _n ///
            "\begin{table}[htb]" _n ///
            "\centering" _n ///
            "\caption{Comparison of Different \texttt{cftemp} Methods (`title_`source'')}" _n ///
            "\label{cftemp-comp}" _n ///
            "\begin{threeparttable}" _n ///
            "\scalebox{0.75}{" _n ///
            "\begin{tabular}{llcccccc}" _n ///
            "\toprule" _n ///
            "Dataset & \multicolumn{1}{c}{Method} & Coef & t-Stat & \(\omega_{C \text{ or } H}\) & \(\sigma^2_{e_{C \text{ or } H}}\) & \(\omega_Y\) & Bias \\" _n ///
            "\midrule" _n ///
            "``source'_bias_table_under_10'" _n ///
            "\cmidrule(lr){2-8}  & \textit{Over 90 Bin} \\" _n ///
            "``source'_bias_table_over_90'" _n ///
            "\hline \hline" _n ///
            "\end{tabular}" _n ///
            "}" _n ///
            "\begin{tablenotes}" _n ///
            "\footnotesize \textit{Notes:} All temperatures are in \degree F. `sample_`source''" _n ///
            "\end{tablenotes}" _n ///
            "\end{threeparttable}" _n ///
            "\end{table}" _n ///
            "\end{landscape}" _n ///
            "\restoregeometry" _n
      file close bias_table_`source'

      * Power Table
      file open power_table_`source' using "`power_table_tex'", write replace
      file write power_table_`source' ///
            "\clearpage" _n ///
            "\thispagestyle{empty}" _n ///
            "\newgeometry{top=1in, bottom=1in, left=0.3in, right=0.3in}" _n ///
            "\begin{landscape}" _n ///
            "\begin{table}[htb]" _n ///
            "\centering" _n ///
            "\caption{Comparison of Different \texttt{cftemp} Methods (`title_`source'')}" _n ///
            "\label{cftemp-comp}" _n ///
            "\begin{threeparttable}" _n ///
            "\scalebox{0.70}{" _n ///
            "\begin{tabular}{llcccccc}" _n ///
            "\toprule" _n ///
            "\multirow{2}{*}{Dataset} & \multirow{2}{*}{Method} & \multicolumn{2}{c}{Linear} & \multicolumn{2}{c}{Quadratic} & \multicolumn{2}{c}{Cubic} \\" _n ///
            " & & Coef & t-Stat & Coef & t-Stat & Coef & t-Stat \\" _n ///
            "\midrule" _n ///
            "``source'_row_under_10'" _n ///
            "\cmidrule(lr){2-8}  & \textit{Over 90 Bin} \\" _n ///
            "``source'_row_over_90'" _n ///
            "\hline \hline" _n ///
            "\end{tabular}" _n ///
            "}" _n ///
            "\begin{tablenotes}" _n ///
            "\footnotesize \textit{Notes:} All temperatures are in \degree F. `sample_`source''" _n ///
            "\end{tablenotes}" _n ///
            "\end{threeparttable}" _n ///
            "\end{table}" _n ///
            "\end{landscape}" _n ///
            "\restoregeometry" _n
      file close power_table_`source'

      local k = `k' + 1
}