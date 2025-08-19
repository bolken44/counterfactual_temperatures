#!/bin/bash

#SBATCH --job-name=ushapes
#SBATCH --mail-type=all
#SBATCH --time=100:00:00

############ Replicators should change the following lines below ############
# Module names and locations for Stata, Python, Anaconda
export stata_ver="stata/17/mp"
export stata_path="/home/software/econ/modulefiles"
export python="python/3.9.4"
export conda_path="/orcd/software/core/001/centos7/pkg/miniforge/24.3.0-0/etc/profile.d/conda.sh"

# Root paths
export data="/orcd/pool/003/hnaka24/climate/repkit/data/"
export repkit="/orcd/home/002/hnaka24/climate/repkit/"

# Switches

#############################################################################
# 0. Setup

# Main directories
export code="${repkit}/code/"
export output="${repkit}/output"
export log="${repkit}/log/"

# Data folders
export raw="${data}/raw/"
export temperature="${data}/temperature/"
export outcomes="${data}/outcomes/"

# Code folders
export ado="${code}/ado/"
export do="${code}/do/"

# Output folders
export intermediate="${output}/intermediate/"
export density="${output}/figures/density/"

# Change directory to main code folder
cd "$do"

# Make directories
mkdir -p "$temperature"
mkdir -p "$output"
mkdir -p "$output/intermediate"
mkdir -p "$output/tables"
mkdir -p "$output/figures"
mkdir -p "$output/figures/simulations"
mkdir -p "$output/figures/real_outcomes"
mkdir -p "$output/figures/density"
mkdir -p "$output/figures/density/allbins"
mkdir -p "$output/figures/density/extreme"
mkdir -p "$log"

# Save variables from submission line
export partition=${SLURM_JOB_PARTITION:-default_partition}
export mailuser=${SLURM_MAIL_USER:-user@example.com}

##################################
# 1. Data Retrieval and Cleaning
echo "Process raw data"
process_id=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/1_1_processERA5.txt 1_1_processERA5.sbatch | awk '{print $4}')
# process_id2=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/1_2_processPRISM.txt 1_2_processPRISM.sbatch | awk '{print $4}')
# process_id3=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/1_3_processGHCN.txt 1_3_processGHCN.sbatch | awk '{print $4}')

##################################
# 2. Construct Counterfactual Temperature Controls
echo "Construct counterfactual temperature datasets"
# cftemp_id=$(sbatch --depend=afterok:$process_id:$process_id3 --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/2_process_cftemp.txt 2_process_cftemp.sbatch | awk '{print $4}')

##################################
# 3. Simulations
echo "Run simulations and make Tables A1, A2, Figures 4, 5, 6c, 7, 9"
# simulation_id=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/3_1_simulations.txt 3_1_simulations.sbatch | awk '{print $4}') #--depend=afterok:$cftemp_id

echo "Append parallelized output"
# append_id=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/3_2_append_files.txt 3_2_append_files.sbatch | awk '{print $4}') #--depend=afterok:$simulation_id 

echo "Make Figures 8, 10, "
# plot_id=$(sbatch --depend=afterok:$append_id --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/3_3_density_plots.txt 3_3_density_plots.sbatch | awk '{print $4}')

##################################
# 4. Real Outcome Applications (Figure 11, A11-A15)
echo "Applications with real outcomes"
# real_id=$(sbatch --depend=afterok:$cftemp_id --export=ALL --partition=$partition --mail-user=$mailuser --output=../../log/4_real_outcomes.txt 4_real_outcomes.sbatch | awk '{print $4}')