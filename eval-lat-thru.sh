#!/bin/bash
workload=("a" "b" "c" "d")
rate=(80000 120000 160000 180000)

for i in $(seq 0 0)
do
    for (( r=30; r<=80; r+=10))
    do
        rate=$(($r * 1000))
#        bash eval.sh run ${workload[$i]} ${rate[$i]} baseline-a-$r 4 baseline
        bash eval.sh load ${workload[$i]} ${rate[$i]} rubble-a-8-$r 4 rubble
    done
done
