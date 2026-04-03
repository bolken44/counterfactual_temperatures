#!/bin/bash
#SBATCH --job-name=emulator
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --array=1,2,4,11
#SBATCH --partition=sched_mit_econ
#SBATCH --output=/orcd/home/002/hnaka24/climate/log/emulator/master_%A.txt

#SBATCH --mem=50GB
#SBATCH --time=5:00:00

#SBATCH --mail-type=all

# you should be on vlogin
module purge
module use /home/software/econ/modulefiles
module load stata/17/mp
STATATMP="/orcd/scratch/orcd/001/$USER/"
export STATATMP

export data="/orcd/pool/003/hnaka24/climate/data/"
export home="/orcd/home/002/hnaka24/climate/"

echo "Run simulations with task ID: $SLURM_ARRAY_TASK_ID"
stata-mp -b do /orcd/home/002/hnaka24/climate/emulator/simulate_emu.do ${data} ${home} ${SLURM_ARRAY_TASK_ID}