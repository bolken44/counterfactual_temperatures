#!/bin/bash
#SBATCH --job-name=3_analysis
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=160GB
#SBATCH --time=10:30:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

stata-mp -b do 3_1_simulations.do
stata-mp -b do 3_2_real_outcomes.do