#!/bin/bash
#SBATCH --job-name=era5_land_download_prep
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --partition=mit_normal

#SBATCH --mem=40GB
#SBATCH --time=12:00:00

#SBATCH --mail-type=all
#SBATCH --output=/orcd/home/002/hnaka24/climate/log/emulator/era5_land_download_prep_%j.txt

module purge
source /orcd/software/core/001/centos7/pkg/miniforge/24.3.0-0/etc/profile.d/conda.sh
conda activate climate

echo "Starting ERA5 Land download and processing. You should be on -login and mit_normal"
echo "Job ID: $SLURM_JOB_ID"

# Change to the script directory
cd /orcd/home/002/hnaka24/climate/emulator/

# Step 1: Download ERA5 Land data
echo "Step 1: Downloading ERA5 Land data..."
python download_era5_land.py

# Step 2: Process and prepare sheets
echo "Step 2: Processing ERA5 Land data and preparing sheets..."
if [ $? -eq 0 ]; then
  python prep_sheets_era5_land.py #_lastcommit
fi

echo "Completed ERA5 Land download and processing"

