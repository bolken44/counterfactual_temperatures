#!/bin/bash
#SBATCH --job-name=processGHCN
#SBATCH --ntasks=1                        # number of scripts that can be run simultaneously
#SBATCH --cpus-per-task=4                 # Each script gets 8 CPU cores
#SBATCH --array=29,64-72,109-112,163-165,173-174,191-198,211-217,287,289


#SBATCH --mem=24GB                        # Total memory allocation
#SBATCH --time=12:00:00                   # Adjust time as needed
#SBATCH --partition=sched_mit_econ

#SBATCH --mail-type=all                  # send email on job start, end and fault
#SBATCH --mail-user=hnakazawa@povertyactionlab.org
#SBATCH --output=/dev/null

source /orcd/software/core/001/centos7/pkg/miniforge/24.3.0-0/etc/profile.d/conda.sh
conda activate climate
module load python/3.9.4

which python
python --version

python climate/00_processGHCN.py > climate/log/00_processGHCN/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.txt 2>&1