#!/bin/bash
#SBATCH --nodes=32                      # number of nodes requested
#SBATCH --ntasks=32                     # number of tasks (default: 1)
#SBATCH --ntasks-per-node=1             # number of tasks per node (default: whole node
#SBATCH --cpus-per-task=40              # number of CPUs per task
#SBATCH --partition=all                 # partition to run in (all or maxwell)
#SBATCH --job-name=CAUSAL               # job name
#SBATCH --output=CAUSAL-%N-%j.out       # output file name
#SBATCH --error=CAUSAL-%N-%j.err        # error file name
#SBATCH --time=1:00:00                  # runtime requested
#SBATCH --mail-user=ayan.paul@desy.de   # notification email
#SBATCH --mail-type=END,FAIL            # notification type
#SBATCH --export=ALL
export LD_PRELOAD=""


# run the application:
srun Rscript causal_shapley_script_cluster.R ${1}
