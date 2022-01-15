#!/bin/bash

cp -r ../configuration_files/death/CO* .

for dir1 in CO1 CO2 CO3 CO4 CO5 CO6
do
    cd ${dir1}
    for dir2 in SS
    do
        cd ${dir2}
        cp ../../causal_shapley_script_cluster_parallel.R .
        rm -rf logs data causality-*
        mkdir logs
        mkdir data
        cd data
        case ${dir2} in
            EC)
                cp ../../../../../data/East_Coast*.csv .
            ;;
            WC)
                cp ../../../../../data/West_Coast*.csv .
            ;;
            SS)
                cp ../../../../../data/Southern_States*.csv .
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
