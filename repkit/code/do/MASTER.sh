#!/bin/bash

#SBATCH --job-name=u_shapes
#SBATCH --time=72:00:00
#SBATCH --partition=sched_mit_econ

#SBATCH --mail-type=all
#SBATCH --mail-user=hnakazawa@povertyactionlab.org
#SBATCH --output=/dev/null

# Load Stata
module purge
module use /home/software/econ/modulefiles
module load stata/17/mp
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

# Set file paths
export root="/orcd/home/002/hnaka24/climate/"

# Data Retrieval and Cleaning
echo "Cleaning data"
clean_id=$(sbatch --export=ALL --output=$output $main_path/.sbatch | awk '{print $4}')

# Construct Counterfactual Temperature Controls
echo "Construct counterfactual temperature datasets"
cftemp_id=$(sbatch --depend=afterok:$clean_id --export=ALL --output=$output $main_path/process_cftemp.sbatch | awk '{print $4}')

# Simulations (Figure 4, Figure 5, Figure 6c, Figure 7, Figure 9) and Real Outcome Applications (Figure 11)
echo "Simulations and real outcome applications"
cftemp_id=$(sbatch --depend=afterok:$clean_id --export=ALL --output=$output $main_path/analysis.sbatch | awk '{print $4}')

# Bias table (Table 2)
echo "Make Table 2"
bias_table_id=$(sbatch --depend=afterok:$cftemp_id --export=ALL --output=$output $main_path/parallel_bias_table.sbatch | awk '{print $4}')
append_id=$(sbatch --depend=afterok:$bias_table_id --export=ALL --output=$output $main_path/append_files.sbatch | awk '{print $4}')

# Power table (Table 3)
echo "Make Table 3"
power_table_id=$(sbatch --depend=afterok:$cftemp_id --export=ALL --output=$output $main_path/parallel_power_table.sbatch | awk '{print $4}')
append_id2=$(sbatch --depend=afterok:$power_table_id --export=ALL --output=$output $main_path/append_files.sbatch | awk '{print $4}')

# Density plot (Figure 8, 10)
echo "Make Figures 8, 10, "
bias_table_id=$(sbatch --depend=afterok:$append_id:$append_id2 --export=ALL --output=$output $main_path/density_plots.sbatch | awk '{print $4}')