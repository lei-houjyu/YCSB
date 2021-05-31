#!/bin/bash

set -x

if [ $# -lt 7 ]; then
    echo "Usage: bash eval.sh replicator_port ip_0 ip_1 head_port tail_port mode(run or load) workload"
    exit
fi

port=$1
ip_0=$2
ip_1=$3
head_port=$4
tail_port=$5

head_0=${ip_0}:${head_port}
head_1=${ip_1}:${head_port}
tail_0=${ip_1}:${tail_port}
tail_1=${ip_0}:${tail_port}

echo replicator at localhost:$port
echo head_0 at $head_0 tail_0 at $tail_0
echo head_1 at $head_1 tail_1 at $tail_1

# start two tail nodes first
ssh ${USER}@${ip_0} "cd YCSB-tail; nohup bash node.sh /mnt/sdb/rocksdb-tail ${tail_port} tail null > nohup.out 2>&1 &"
ssh ${USER}@${ip_1} "cd YCSB-tail; nohup bash node.sh /mnt/sdb/rocksdb-tail ${tail_port} tail null > nohup.out 2>&1 &"
ssh ${USER}@${ip_0} "cd YCSB-tail; until grep 'Server started' nohup.out > /dev/null; do sleep 1; done"
ssh ${USER}@${ip_1} "cd YCSB-tail; until grep 'Server started' nohup.out > /dev/null; do sleep 1; done"

# start two head nodes first
ssh ${USER}@${ip_0} "cd YCSB-head; nohup bash node.sh /mnt/sdb/rocksdb-head ${head_port} head ${tail_0} > nohup.out 2>&1 &"
ssh ${USER}@${ip_1} "cd YCSB-head; nohup bash node.sh /mnt/sdb/rocksdb-head ${head_port} head ${tail_1} > nohup.out 2>&1 &"
ssh ${USER}@${ip_0} "cd YCSB-head; until grep 'Server started' nohup.out > /dev/null; do sleep 1; done"
ssh ${USER}@${ip_1} "cd YCSB-head; until grep 'Server started' nohup.out > /dev/null; do sleep 1; done"

# start the replicator
bash replicator.sh 8980 $head_0 $tail_0 $head_1 $tail_1 > replicator.out 2>&1 &

# start ycsb
bash $6.sh $7 localhost:$port > ycsb.out 2>&1
grep Throughput ycsb.out

# kill replicator, heads, and tails
bash kill.sh $ip_0 $ip_1