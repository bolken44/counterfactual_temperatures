#!/bin/bash
#SBATCH --job-name=3_3_other_sim
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --array=1-5

#SBATCH --mem=40GB
#SBATCH --time=8:00:00

#SBATCH --mail-type=all

module purge
module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

mkdir -p ../../log/3_3_other_sim/

echo "Make Figures 7(c)(d) and A4(a)(b)"
stata-mp -b do 3_3_other_sim.do ${data} ${repkit} ${SLURM_ARRAY_TASK_ID}