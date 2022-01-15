#!/bin/bash
#SBATCH --nodes=1                       # number of nodes requested
#SBATCH --ntasks=1                      # number of tasks (default: 1)
#SBATCH --cpus-per-task=40              # number of CPUs per task
#SBATCH --partition=all                 # partition to run in (all or maxwell)
#SBATCH --job-name=CO5-EC               # job name
#SBATCH --output=logs/CO5-EC-%N-%j.out  # output file name
#SBATCH --error=logs/CO5-EC-%N-%j.err   # error file name
#SBATCH --time=1:00:00                  # runtime requested
#SBATCH --mail-user=ayan.paul@desy.de   # notification email
#SBATCH --mail-type=END,FAIL            # notification type
#SBATCH --export=ALL
#SBATCH --array 1-8
export LD_PRELOAD=""


# run the application:
Rscript causal_shapley_script_cluster_parallel.R ${1}
