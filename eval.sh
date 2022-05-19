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

# start nodes from tail to head
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; sudo killall primary_node tail_node dstat iostat > /dev/null 2>&1;"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; sudo bash clean.sh 2 > /dev/null 2>&1;"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; sudo bash change-mode.sh ${mode}"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; sudo bash create_cgroups.sh > /dev/null 2>&1"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50051 10.10.1.3:50053 1 > primary-1.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50052 10.10.1.3:50054 2 > primary-2.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50053 10.10.1.1:50050 1 > tail-1.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50054 10.10.1.1:50050 2 > tail-2.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; nohup sudo bash dstat.sh > /dev/null 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; nohup sudo bash iostat.sh > /dev/null 2>&1 &"

ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; sudo killall primary_node tail_node dstat iostat > /dev/null 2>&1;"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; sudo bash clean.sh 2 > /dev/null 2>&1;"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; sudo bash change-mode.sh ${mode}"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; sudo bash create_cgroups.sh > /dev/null 2>&1"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50051 10.10.1.2:50053 1 > primary-1.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50052 10.10.1.2:50054 2 > primary-2.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50053 10.10.1.1:50050 1 > tail-1.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50054 10.10.1.1:50050 2 > tail-2.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; nohup sudo bash dstat.sh > /dev/null 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; nohup sudo bash iostat.sh > /dev/null 2>&1 &"

# start the replicator
sudo killall java
# replicator_args='-p shard=4 -p head1=10.10.1.2:50051 -p tail1=10.10.1.3:50053 -p head2=10.10.1.2:50052 -p tail2=10.10.1.3:50054 -p head3=10.10.1.3:50051 -p tail3=10.10.1.2:50053 -p head4=10.10.1.3:50052 -p tail4=10.10.1.2:50054'
replicator_args='-p shard=4 -p head1=10.10.1.2:50051 -p tail1=10.10.1.3:50053 -p head2=10.10.1.2:50052 -p tail2=10.10.1.3:50054 -p head3=10.10.1.3:50051 -p tail3=10.10.1.2:50053 -p head4=10.10.1.3:50052 -p tail4=10.10.1.2:50054'
./bin/ycsb.sh replicator rocksdb -s -P workloads/workload${workload} -p port=50050 $replicator_args -p replica=2 > replicator.out 2>&1 &

# start ycsb
sleep_ms=1000
bash $phase.sh $workload localhost:50050 4 $sleep_ms $rate 16 > ycsb.out 2>&1
grep Throughput ycsb.out
cp ycsb.out ycsb-${suffix}.out
python3 plot-thru.py ycsb-${suffix}.out 10

# kill replicator, heads, and tails
ssh ${USER}@10.10.1.2 "sudo killall primary_node tail_node dstat iostat"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; cp primary-1.out primary-1-${suffix}.out; cp primary-2.out primary-2-${suffix}.out; cp tail-1.out tail-1-${suffix}.out; cp tail-2.out tail-2-${suffix}.out; cp dstat.csv dstat-${suffix}.csv; cp iostat.out iostat-${suffix}.out"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; python3 plot-dstat.py dstat-${suffix}.out 10"
ssh ${USER}@10.10.1.2 "cd /mnt/code/my_rocksdb/rubble; python3 plot-iostat.py iostat-${suffix}.out 10"

ssh ${USER}@10.10.1.3 "sudo killall primary_node tail_node dstat iostat"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; cp primary-1.out primary-1-${suffix}.out; cp primary-2.out primary-2-${suffix}.out; cp tail-1.out tail-1-${suffix}.out; cp tail-2.out tail-2-${suffix}.out; cp dstat.csv dstat-${suffix}.csv; cp iostat.out iostat-${suffix}.out"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; python3 plot-dstat.py dstat-${suffix}.out 10"
ssh ${USER}@10.10.1.3 "cd /mnt/code/my_rocksdb/rubble; python3 plot-iostat.py iostat-${suffix}.out 10"

sudo killall java