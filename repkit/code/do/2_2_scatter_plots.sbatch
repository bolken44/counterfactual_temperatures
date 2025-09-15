#!/bin/bash
#SBATCH --job-name=2_2_scatter_plots
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=40GB
#SBATCH --time=10:30:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

mkdir -p ../../log/2_2_scatter_plots/

stata-mp -b do 2_2_scatter_plots.do ${data} ${repkit}