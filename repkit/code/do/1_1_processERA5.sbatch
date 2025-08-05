#!/bin/bash
#SBATCH --job-name=1_2_processPRISM
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=40GB
#SBATCH --time=1:00:00

#SBATCH --mail-type=all

source $conda
conda activate climate
module load $python

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

echo "Processing ERA5"
mkdir -p ../../log/1_1_processERA5/

python 1_1_1_downloadERA5.py > ../../log/1_1_processERA5/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.txt 2>&1
stata-mp -b do 1_1_2_processERA5.do