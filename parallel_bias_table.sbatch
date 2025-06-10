#!/bin/bash
#SBATCH --job-name=bias_table
#SBATCH --ntasks=1                        # number of scripts that can be run simultaneously
#SBATCH --cpus-per-task=4                 # Each script gets 8 CPU cores
#SBATCH --array=1-12

#SBATCH --mem=80GB                        # Total memory allocation
#SBATCH --time=12:00:00                   # Adjust time as needed
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

stata-mp -b do climate/parallel_bias_table.do ${SLURM_ARRAY_TASK_ID}