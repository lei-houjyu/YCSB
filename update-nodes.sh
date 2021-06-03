#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: bash update-nodes.sh shard_num ip_0 ip_1 ... ip_N"
    exit
fi

sudo killall java
shard_num=$1
shift
for ip in $*
do
    for shard in $(seq 1 $shard_num)
    do
        ssh ${USER}@${ip} "cd YCSB-${shard}; git reset --hard HEAD; git pull origin lhy_dev; bash build.sh"
    done
done