#!/bin/bash
#SBATCH --job-name=4_parallel_tables
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
mkdir -p ../../log/4_1_parallel_bias_table/
mkdir -p ../../log/4_2_parallel_power/

stata-mp -b do climate/4_1_parallel_bias_table.do ${SLURM_ARRAY_TASK_ID} ${data} ${repkit}
stata-mp -b do climate/4_2_parallel_power.do ${SLURM_ARRAY_TASK_ID} ${data} ${repkit}