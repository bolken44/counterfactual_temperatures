#!/bin/bash
#SBATCH --job-name=3_2_analysis
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=40GB
#SBATCH --time=3:00:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

mkdir -p ../../log/3_2_analysis/

echo "Make Tables A1, A2"
stata-mp -b do 3_2_1_bias_table.do ${data} ${repkit}

echo "Append parallelized output"
stata-mp -b do 3_2_2_append_files.do ${data} ${repkit}

echo "Make Figures 8, 10, "
stata-mp -b do 3_2_3_density_plots.do ${data} ${repkit}