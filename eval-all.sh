#!/bin/bash
workload=("a" "b" "c" "d")
rate=(80000 120000 160000 180000)

for i in $(seq 3 3)
    do
        echo workload ${workload[$i]} rate ${rate[$i]} op/sec
        bash eval.sh run ${workload[$i]} ${rate[$i]} baseline-${workload[$i]} 4 baseline
        # bash eval.sh run ${workload[$i]} ${rate[$i]} rubble-${workload[$i]} 4 rubble
    done

bash eval.sh load a 60000 baseline-load 4 baseline
# bash eval.sh load a 60000 rubble-load 4 rubble
