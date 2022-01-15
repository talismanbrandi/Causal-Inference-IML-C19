#!/bin/bash
for i in {0..19}
do
    cp ../configuration_files/configurations_${i}.json
    sbatch sbatch.sh configurations_${i}.json
done
