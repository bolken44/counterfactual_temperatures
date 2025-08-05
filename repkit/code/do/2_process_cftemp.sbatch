#!/bin/bash
#SBATCH --job-name=2_process_cftemp
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --array=1-36%3

#SBATCH --mem=160GB
#SBATCH --time=10:30:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

echo "Running task ID: $SLURM_ARRAY_TASK_ID"

stata-mp -b do 2_process_cftemp.do ${SLURM_ARRAY_TASK_ID}