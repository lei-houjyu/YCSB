#!/bin/bash
workload=("a" "b" "c" "d")
rate=(80000 200000 250000 200000)

for i in $(seq 0 3)
    do
        echo workload ${workload[$i]} rate ${rate[$i]} op/sec
        bash eval.sh run ${workload[$i]} ${rate[$i]} baseline-${workload[$i]} 4 baseline
        bash eval.sh run ${workload[$i]} ${rate[$i]} rubble-${workload[$i]} 4 rubble
    done