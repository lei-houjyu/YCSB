#!/bin/bash
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

for i in $(seq 0 3)
    do
        echo workload ${workload[$i]} rate ${rate[$i]} op/sec
        bash eval.sh run ${workload[$i]} ${rate[$i]} baseline-${workload[$i]} 4 baseline
        disable_offload
        bash eval.sh run ${workload[$i]} ${rate[$i]} rubble-${workload[$i]} 4 rubble
        enable_offload
        bash eval.sh run ${workload[$i]} ${rate[$i]} rubble-${workload[$i]}-offload 4 rubble
    done

exit

bash eval.sh load a 90000 baseline-load 4 baseline
disable_offload
bash eval.sh load a 90000 rubble-load 4 rubble
enable_offload
bash eval.sh load a 90000 rubble-load-offload 4 rubble
