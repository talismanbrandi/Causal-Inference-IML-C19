#!/bin/bash

cp -r ../../../notebooks/configuration_files/CO* .

for dir1 in CO4 CO5 CO6
do
    cd ${dir1}
    for dir2 in EC WC SS
    do
        cd ${dir2}
        cp ../../causal_shapley_script_cluster_parallel.R .
        mkdir logs
        mkdir data
        cd data
        case ${dir2} in
            EC)
                cp ../../../../../../data/East_Coast*.csv .
            ;;
            WC)
                cp ../../../../../../data/West_Coast*.csv .
            ;;
            SS)
                cp ../../../../../../data/Southern_States*.csv .
            ;;
        esac
        cd ..
        sed -e "s/CAUSAL/${dir1}-${dir2}/" ../../sbatch.sh > sbatch.sh
        sbatch sbatch.sh configurations-FEB-JUL-${dir2}-NC.json
        sbatch sbatch.sh configurations-JUL-JAN-${dir2}-NC.json
        sbatch sbatch.sh configurations-FEB-JUL-${dir2}-CO.json 
        sbatch sbatch.sh configurations-JUL-JAN-${dir2}-CO.json
        cd ..
    done
    cd ..
done
