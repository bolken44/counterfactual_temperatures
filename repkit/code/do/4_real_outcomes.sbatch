#!/bin/bash
#SBATCH --job-name=4_real_outcomes
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

mkdir -p ../../log/4_real_outcomes/

stata-mp -b do 4_real_outcomes.do