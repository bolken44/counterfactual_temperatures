#!/bin/bash
#SBATCH --job-name=1_1_processERA5
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=240GB
#SBATCH --time=48:00:00

#SBATCH --mail-type=all

module purge
source $conda_path
conda init
conda activate climate
module load $python
module load gcc/11.2.0
module load cmake/3.17.3

module use $stata_path
module load $stata_ver
STATATMP="/nobackup1/$USER/tmp"
export STATATMP
echo "$stata_path, $stata_ver, $STATATMP"

export startyear=1970
export endyear=2019

echo "Processing ERA5"
mkdir -p ../../log/1_1_processERA5/

python 1_1_1_downloadERA5.py -s "${startyear}-01-01" -e "${endyear}-12-31" -m 100 -w 5 -sy "${startyear}" -ey "${endyear}" -data "${data}" -repkit "${repkit}" > ../../log/1_1_processERA5/${SLURM_JOB_ID}.txt 2>&1
stata-mp -b do 1_1_2_processERA5.do ${data} ${repkit} ${startyear} ${endyear}