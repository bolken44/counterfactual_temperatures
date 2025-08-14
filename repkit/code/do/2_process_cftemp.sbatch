#!/bin/bash
#SBATCH --job-name=2_process_cftemp
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --array=1-24

#SBATCH --mem=160GB
#SBATCH --time=10:30:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

echo "Running task ID: $SLURM_ARRAY_TASK_ID"
mkdir -p ../../log/2_process_cftemp/

stata-mp -b do 2_process_cftemp.do ${data} ${repkit} ${SLURM_ARRAY_TASK_ID}