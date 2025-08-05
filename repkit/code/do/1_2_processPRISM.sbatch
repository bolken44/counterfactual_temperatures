#!/bin/bash
#SBATCH --job-name=1_2_processPRISM
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

echo "Processing PRISM"

stata-mp -b do 1_2_processPRISM.do