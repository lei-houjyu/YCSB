#!/bin/bash

if [ $# != 4 ]; then
    echo "Usage: bash eval-all.sh client_num shard_num replication_factor suffix"
    exit
fi

client_num=$1
shard_num=$2
rf=$3
suffix=$4

# workload=("a" "b" "c" "d")
# rate=(80000 120000 140000 240000)

workload=("a" "d")
rate=(80000 240000)

change_offload()
{
    ip=$1
    code=$2
    ssh ${USER}@${ip} "rm /sys/kernel/config/nvmet/ports/1/subsystems/testsubsystem; sleep 1; echo ${code} > /sys/kernel/config/nvmet/subsystems/testsubsystem/attr_offload; sleep 1; ln -s /sys/kernel/config/nvmet/subsystems/testsubsystem/ /sys/kernel/config/nvmet/ports/1/subsystems/testsubsystem"
}

enable_offload()
{
    for (( i=0; i<${rf}; i++ )); do
        ip="10.10.1."$(($i + 2))
        change_offload $ip 1
    done
}

disable_offload()
{
    for (( i=0; i<${rf}; i++ )); do
        ip="10.10.1."$(($i + 2))
        change_offload $ip 0
    done
}

disable_offload
bash eval.sh load a 90000 rubble-load-$suffix 4 rubble $shard_num $rf
enable_offload
bash eval.sh load a 90000 rubble-offload-load-$suffix 4 rubble $shard_num $rf
bash eval.sh load a 90000 baseline-load-$suffix 4 baseline $shard_num $rf

for idx in $(seq 0 1)
do
    echo workload ${workload[$idx]} rate ${rate[$idx]} op/sec
    disable_offload
    bash eval.sh run ${workload[$idx]} ${rate[$idx]} rubble-${workload[$idx]}-$suffix 4 rubble $shard_num $rf
    enable_offload
    bash eval.sh run ${workload[$idx]} ${rate[$idx]} rubble-offload-${workload[$idx]}-$suffix 4 rubble $shard_num $rf
    bash eval.sh run ${workload[$idx]} ${rate[$idx]} baseline-${workload[$idx]}-$suffix 4 baseline $shard_num $rf
done
