# Replication Package for "With or Without U?"

## Setup
- Set up a anaconda virtual environment and 
`environment.yml`

- Open `repkit/code/MASTER.sh` and change the paths and switches specified at the top of the file.

- To download the ERA 5 Land temperature raw data, follow the directions on . You must create a .csdapirc file in your home directory of the server.

## Running the script
This code is meant to be run on a high-computing cluster (HPC). On the terminal, run
```
sbatch --partition=sched_mit_econ --mail-user=hnakazawa@povertyactionlab.org --output=log/MASTER_%A.txt code/MASTER.sh
```
setting the following arguments as appropriate.
- partition: name of the partition that this code runs on the high-performance cluster (HPC)
- mail-user: email address that notifications from the HPC arrive