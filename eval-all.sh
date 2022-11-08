#!/bin/bash

if [ $# != 4 ]; then
    echo "Usage: bash eval-all.sh client_num shard_num replication_factor suffix"
    exit
fi

client_num=$1
shard_num=$2
rf=$3
suffix=$4

workload=("a" "b" "c" "d")
rate=(80000 120000 140000 240000)

change_offload()
{
    ip=$1
    code=$2
    ssh ${USER}@${ip} "rm /sys/kernel/config/nvmet/ports/1/subsystems/testsubsystem; sleep 1; echo ${code} > /sys/kernel/config/nvmet/subsystems/testsubsystem/attr_offload; sleep 1; ln -s /sys/kernel/config/nvmet/subsystems/testsubsystem/ /sys/kernel/config/nvmet/ports/1/subsystems/testsubsystem"
}

enable_offload()
{
change_offload 10.10.1.2 1
change_offload 10.10.1.3 1
}

disable_offload()
{
change_offload 10.10.1.2 0
change_offload 10.10.1.3 0
}

bash eval.sh load a 90000 baseline-load-$suffix 4 baseline $shard_num $rf
disable_offload
bash eval.sh load a 90000 rubble-load-$suffix 4 rubble $shard_num $rf
enable_offload
bash eval.sh load a 90000 rubble-offload-load-$suffix 4 rubble $shard_num $rf

for i in $(seq 0 0)
do
    echo workload ${workload[$i]} rate ${rate[$i]} op/sec
    bash eval.sh run ${workload[$i]} ${rate[$i]} baseline-${workload[$i]}-$suffix 4 baseline $shard_num $rf
    disable_offload
    bash eval.sh run ${workload[$i]} ${rate[$i]} rubble-${workload[$i]}-$suffix 4 rubble $shard_num $rf
    enable_offload
    bash eval.sh run ${workload[$i]} ${rate[$i]} rubble-offload-${workload[$i]}-$suffix 4 rubble $shard_num $rf
done