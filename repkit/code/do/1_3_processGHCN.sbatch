#!/bin/bash
#SBATCH --job-name=1_3_processGHCN
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=40GB
#SBATCH --time=1:00:00

#SBATCH --mail-type=all

source $conda
conda activate climate
module load $python

echo "Running task ID: $SLURM_ARRAY_TASK_ID"
mkdir -p ../../log/1_3_processGHCN/

python 1_3_processGHCN.py ${raw} > ../../log/1_3_processGHCN/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.txt 2>&1