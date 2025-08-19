#!/bin/bash
#SBATCH --job-name=3_1_simulations
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --array=1,6

#SBATCH --mem=100GB
#SBATCH --time=48:00:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

mkdir -p ../../log/3_1_simulations/

echo "Run simulations with task ID: $SLURM_ARRAY_TASK_ID"
stata-mp -b do 3_1_simulations.do ${data} ${repkit} ${SLURM_ARRAY_TASK_ID}