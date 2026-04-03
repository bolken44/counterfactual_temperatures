#!/bin/bash
#SBATCH --job-name=power_table
#SBATCH --ntasks=1                        # number of scripts that can be run simultaneously
#SBATCH --cpus-per-task=4                 # Each script gets 8 CPU cores
#SBATCH --array=1-8

#SBATCH --mem=160GB                        # Total memory allocation
#SBATCH --time=10:30:00                   # Adjust time as needed
#SBATCH --partition=sched_mit_econ

#SBATCH --mail-type=all                  # send email on job start, end and fault
#SBATCH --mail-user=hnakazawa@povertyactionlab.org
#SBATCH --output=/dev/null

module purge
module use /home/software/econ/modulefiles
module load stata/17/mp
STATATMP="/nobackup1/$USER/tmp"
export STATATMP

echo "Running task ID: $SLURM_ARRAY_TASK_ID"

stata-mp -b do climate/parallel_power.do ${SLURM_ARRAY_TASK_ID}