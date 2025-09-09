#!/bin/bash
#SBATCH --job-name=3_3_density_plots
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=40GB
#SBATCH --time=1:00:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

mkdir -p ../../log/3_3_density_plots/

stata-mp -b do 3_3_density_plots.do ${data} ${repkit}