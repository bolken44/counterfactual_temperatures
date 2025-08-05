#!/bin/bash

#SBATCH --job-name=ushapes
#SBATCH --mail-type=all
#SBATCH --time=10:30:00

##################################
# Replication Package for "With or Without U?"

# On the terminal, run
#      `sbatch --partition=sched_mit_econ --mail-user=hnakazawa@povertyactionlab.org --output=climate/repkit/log/MASTER_%A.txt climate/repkit/code/MASTER.sh`

#     setting the arguments as appropriate.
#     - partition: name of the partition that this code runs on the high-performance cluster (HPC)
#     - mail-user: email address that notifications from the HPC arrive

# In addition, replicators should change the following lines below:

# Module names and locations for Stata, Python, Anaconda
export stata_ver="stata/17/mp"
export stata_path="/home/software/econ/modulefiles"
export python="python/3.9.4"
export conda_path="/orcd/software/core/001/centos7/pkg/miniforge/24.3.0-0/etc/profile.d/conda.sh"

# Root path
export root="/orcd/home/002/hnaka24/climate/repkit"

##################################
# 0. Setup

# Main directories
export repkit="${root}/repkit"
export data="${repkit}/data"
export code="${repkit}/code"
export output="${repkit}/output"
export log="${repkit}/log"

# Data folders
export raw="${data}/raw"
export temperature="${data}/temperature"
export outcomes="${data}/outcomes"

# Code folders
export ado="${code}/ado"
export do="${code}/do"

# Output folders
export intermediate="${output}/intermediate"
export density="${output}/figures/density"

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
mkdir -p "$log"
mkdir -p "$log/bias_table"
mkdir -p "$log/power_table"

# Save variables from submission line
export partition=${SLURM_JOB_PARTITION:-default_partition}
export mailuser=${SLURM_MAIL_USER:-user@example.com}

##################################
# 1. Data Retrieval and Cleaning
#--- Make sure that the following packages are installed on python: numpy, geopy, and tqdm.
echo "Process raw data"
process_id=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=log/1_1_processERA5.txt 1_1_processERA5.sbatch | awk '{print $4}')
process_id2=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=log/1_2_processPRISM.txt 1_2_processPRISM.sbatch | awk '{print $4}')
process_id3=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=log/1_3_processGHCN.txt 1_3_processGHCN.sbatch | awk '{print $4}')

##################################
# 2. Construct Counterfactual Temperature Controls
echo "Construct counterfactual temperature datasets"
cftemp_id=$(sbatch --depend=afterok:$process_id:$process_id3 --export=ALL --partition=$partition --mail-user=$mailuser --output=log/2_process_cftemp.txt 2_process_cftemp.sbatch | awk '{print $4}')

##################################
# 3. Main Analyses: Simulations (Figure 4, Figure 5, Figure 6c, Figure 7, Figure 9) and Real Outcome Applications (Figure 11)
echo "Simulations and real outcome applications"
analysis_id=$(sbatch --export=ALL --partition=$partition --mail-user=$mailuser --output=log/3_analysis.txt 3_analysis.sbatch | awk '{print $4}') #--depend=afterok:$cftemp_id

##################################
# 4. Bias Table (Table 2) and Power Table (Table 3)
# echo "Make Table 2"
# tables_id=$(sbatch --depend=afterok:$analysis_id --export=ALL --partition=$partition --mail-user=$mailuser --output=log/4_parallel_tables.txt 4_parallel_tables.sbatch | awk '{print $4}')
# append_id=$(sbatch --depend=afterok:$tables_id --export=ALL --partition=$partition --mail-user=$mailuser --output=log/4_3_append_files.txt 4_3_append_files.sbatch | awk '{print $4}')

# ##################################
# # 5. Density Plot (Figure 8, 10)
# echo "Make Figures 8, 10, "
# plot_id=$(sbatch --depend=afterok:$append_id --export=ALL --partition=$partition --mail-user=$mailuser --output=log/5_density_plots.txt 5_density_plots.sbatch | awk '{print $4}')