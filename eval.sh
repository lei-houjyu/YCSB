#!/bin/bash

set -x

if [ $# != 5 ]; then
    echo "Usage: bash eval.sh phase(run or load) workload target_rate result_suffix mode"
    exit
fi

phase=$1
workload=$2
rate=$3
suffix=$4
mode=$5

# kill zumbie replicator, heads, and tails
bash prepare.sh 10.10.1.3 10.10.1.4
sleep 5

# start nodes from tail to head

ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash clean.sh > /dev/null 2>&1;"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash change-mode.sh ${mode}"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 10.10.1.4:50052 > primary.out 2>&1"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 10.10.1.1:50050 > tail.out 2>&1"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; nohup sudo bash iostat.sh"

ssh ${USER}@10.10.1.4 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash clean.sh > /dev/null 2>&1;"
ssh ${USER}@10.10.1.4 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash change-mode.sh ${mode}"
ssh ${USER}@10.10.1.4 "cd /mnt/sdb/my_rocksdb/rubble; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 10.10.1.3:50052 > primary.out 2>&1"
ssh ${USER}@10.10.1.4 "cd /mnt/sdb/my_rocksdb/rubble; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 10.10.1.1:50050 > tail.out 2>&1"
ssh ${USER}@10.10.1.4 "cd /mnt/sdb/my_rocksdb/rubble; nohup sudo bash iostat.sh"

# start the replicator
replicator_args='-p shard=2 -p head1=10.10.1.3:50051 -p tail1=10.10.1.4:50052 -p head2=10.10.1.4:50051 -p tail2=10.10.1.3:50052'
./bin/ycsb.sh replicator rocksdb -s -P workloads/workloada -p port=50050 $replicator_args > replicator.out 2>&1 &

# start ycsb
sleep_ms=1000
bash $phase.sh $workload localhost:50050 2 $sleep_ms $rate > ycsb.out 2>&1
grep Throughput ycsb.out
cp ycsb.out ycsb-${suffix}.out
python3 plot-thru.py ycsb-${suffix}.out 10

# kill replicator, heads, and tails
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash wait-pending-jobs.sh primary"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash wait-pending-jobs.sh tail"
ssh ${USER}@10.10.1.3 "sudo killall iostat"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; cp primary.out primary-${suffix}.out; cp tail.out tail-${suffix}.out; cp iostat.out iostat-${suffix}.out"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; python3 plot-iostat.py iostat-${suffix}.out 10"

ssh ${USER}@10.10.1.4 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash wait-pending-jobs.sh primary"
ssh ${USER}@10.10.1.4 "cd /mnt/sdb/my_rocksdb/rubble; sudo bash wait-pending-jobs.sh tail"
ssh ${USER}@10.10.1.4 "sudo killall iostat"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; cp primary.out primary-${suffix}.out; cp tail.out tail-${suffix}.out; cp iostat.out iostat-${suffix}.out"
ssh ${USER}@10.10.1.3 "cd /mnt/sdb/my_rocksdb/rubble; python3 plot-iostat.py iostat-${suffix}.out 10"