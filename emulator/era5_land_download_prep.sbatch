#!/bin/bash
#SBATCH --job-name=era5_land_download_prep
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

#SBATCH --mem=240GB
#SBATCH --time=72:00:00

#SBATCH --mail-type=all
#SBATCH --output=/orcd/home/002/hnaka24/climate/log/emulator/era5_land_download_prep_%j.txt

module purge
module load python/3.9.4                      # need to import every time in sbatch
module load openssl/1.1.1t #only works on vlogin
source $conda_path
conda init
conda activate climate

echo "Starting ERA5 Land download and processing. You should be on -vlogin"
echo "Job ID: $SLURM_JOB_ID"

# Change to the script directory
cd /orcd/home/002/hnaka24/climate/repkit/code/do/

# Step 1: Download ERA5 Land data
# echo "Step 1: Downloading ERA5 Land data..."
# python download_era5_land.py

# Step 2: Process and prepare sheets
echo "Step 2: Processing ERA5 Land data and preparing sheets..."
python prep_sheets_era5_land.py

echo "Completed ERA5 Land download and processing"

