#!/bin/bash

set -x

if [ $# != 6 ]; then
    echo "Usage: bash eval.sh phase(run or load) workload target_rate result_suffix client_num mode"
    exit
fi

phase=$1
workload=$2
rate=$3
suffix=$4
client_num=$5
mode=$6
shard_num=4

# start nodes from tail to head
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; sudo killall primary_node tail_node dstat iostat perf > /dev/null 2>&1;"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; sudo bash clean.sh 2 > /dev/null 2>&1;"
# ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; sudo bash recover.sh 2 > /dev/null 2>&1;"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; sudo bash change-mode.sh ${mode}"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; sudo bash create_cgroups.sh > /dev/null 2>&1"
# ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/primary-1.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./primary_node 50051 10.10.1.3:50053 1 >> primary-1.out 2>&1 &"
# ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/primary-2.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./primary_node 50052 10.10.1.3:50054 2 >> primary-2.out 2>&1 &"
# ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/tail-1.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./tail_node 50053 10.10.1.1:50050 1 >> tail-1.out 2>&1 &"
# ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/tail-2.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./tail_node 50054 10.10.1.1:50050 2 >> tail-2.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50051 10.10.1.3:50053 1 >> primary-1.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50052 10.10.1.3:50054 2 >> primary-2.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50053 10.10.1.1:50050 1 >> tail-1.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50054 10.10.1.1:50050 2 >> tail-2.out 2>&1 &"

ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; sudo killall primary_node tail_node dstat iostat perf > /dev/null 2>&1;"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; sudo bash clean.sh 2 > /dev/null 2>&1;"
# ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; sudo bash recover.sh 2 > /dev/null 2>&1;"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; sudo bash change-mode.sh ${mode}"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; sudo bash create_cgroups.sh > /dev/null 2>&1"
# ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/primary-1.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./primary_node 50051 10.10.1.2:50053 1 >> primary-1.out 2>&1 &"
# ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/primary-2.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./primary_node 50052 10.10.1.2:50054 2 >> primary-2.out 2>&1 &"
# ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/tail-1.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./tail_node 50053 10.10.1.1:50050 1 >> tail-1.out 2>&1 &"
# ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem env HEAPPROFILE=/mnt/data/my_rocksdb/rubble/tail-2.hprof LD_PRELOAD=/usr/local/lib/libtcmalloc.so ./tail_node 50054 10.10.1.1:50050 2 >> tail-2.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50051 10.10.1.2:50053 1 >> primary-1.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./primary_node 50052 10.10.1.2:50054 2 >> primary-2.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50053 10.10.1.1:50050 1 >> tail-1.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ulimit -n 999999; ulimit -c unlimited; nohup sudo cgexec -g cpuset:rubble-cpu -g memory:rubble-mem ./tail_node 50054 10.10.1.1:50050 2 >> tail-2.out 2>&1 &"

ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; nohup sudo bash dstat.sh 0,2,4,6 > /dev/null 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; nohup sudo bash iostat.sh > /dev/null 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; ps aux | grep -E 'mem ./[primary|tail]' > pids.out"

ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; nohup sudo bash dstat.sh 0,2,4,6 > /dev/null 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; nohup sudo bash iostat.sh > /dev/null 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; ps aux | grep -E 'mem ./[primary|tail]' > pids.out"

# start the replicator
sudo killall java
# replicator_args="-p shard=${shard_num} -p head1=10.10.1.2:50051 -p tail1=10.10.1.3:50053 -p head2=10.10.1.2:50052 -p tail2=10.10.1.3:50054 -p head3=10.10.1.3:50051 -p tail3=10.10.1.2:50053 -p head4=10.10.1.3:50052 -p tail4=10.10.1.2:50054"
replicator_args="-p shard=${shard_num} -p client=${client_num} -p head1=10.10.1.2:50051 -p tail1=10.10.1.3:50053 -p head2=10.10.1.2:50052 -p tail2=10.10.1.3:50054 -p head3=10.10.1.3:50051 -p tail3=10.10.1.2:50053 -p head4=10.10.1.3:50052 -p tail4=10.10.1.2:50054"
# replicator_args="-p shard=${shard_num} -p client=${client_num} -p head1=10.10.1.2:50051 -p tail1=10.10.1.3:50053 -p head2=10.10.1.2:50052 -p tail2=10.10.1.3:50054"
# replicator_args="-p shard=${shard_num} -p client=${client_num} -p head1=10.10.1.3:50051 -p tail1=10.10.1.2:50053 -p head2=10.10.1.3:50052 -p tail2=10.10.1.2:50054"
# replicator_args="-p shard=${shard_num} -p client=${client_num} -p head1=10.10.1.2:50051 -p tail1=10.10.1.3:50053"
./bin/ycsb.sh replicator rocksdb -s -P workloads/workload${workload} -p port=50050 $replicator_args -p replica=2 > replicator.out 2>&1 &

# start ycsb
sleep_ms=1000
echo "" > ycsb.out
if [ $phase != load ]; then
    ssh ${USER}@10.10.1.2 "sudo cgset -r cpuset.cpus=0-31,64-95 rubble-cpu"
    ssh ${USER}@10.10.1.3 "sudo cgset -r cpuset.cpus=0-31,64-95 rubble-cpu"

    bash load.sh $workload localhost:50050 $shard_num $sleep_ms 120000 $client_num > ycsb.out 2>&1

    ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/1/primary/db/LOG" &
    ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/2/primary/db/LOG" &
    ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/1/tail/db/LOG" &
    ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/2/tail/db/LOG" &
    ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/1/primary/db/LOG" &
    ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/2/primary/db/LOG" &
    ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/1/tail/db/LOG" &
    ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; bash wait-pending-jobs.sh /mnt/data/db/2/tail/db/LOG" &

    wait

    ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; sudo bash create_cgroups.sh > /dev/null 2>&1"
    ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; sudo bash create_cgroups.sh > /dev/null 2>&1"
fi

ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; nohup top -H -b -d 1 -w 512 > top.out 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; nohup top -H -b -d 1 -w 512 > top.out 2>&1 &"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; nohup bash perf.sh ${suffix} 0,2,4,6 120 > /dev/null 2>&1 &"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; nohup bash perf.sh ${suffix} 0,2,4,6 120 > /dev/null 2>&1 &"
bash $phase.sh $workload localhost:50050 $shard_num $sleep_ms $rate $client_num >> ycsb.out 2>&1
grep Throughput ycsb.out
cp ycsb.out ycsb-${suffix}.out
python3 plot-thru.py ycsb-${suffix}.out 10

# kill replicator, heads, and tails
ssh ${USER}@10.10.1.2 "sudo killall primary_node tail_node dstat iostat perf top"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; bash save-result.sh ${suffix}"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; python3 plot-dstat.py dstat-${suffix}.csv 10 4"
ssh ${USER}@10.10.1.2 "cd /mnt/data/my_rocksdb/rubble; python3 plot-iostat.py iostat-${suffix}.out 10"

ssh ${USER}@10.10.1.3 "sudo killall primary_node tail_node dstat iostat perf top"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; bash save-result.sh ${suffix}"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; python3 plot-dstat.py dstat-${suffix}.csv 10 4"
ssh ${USER}@10.10.1.3 "cd /mnt/data/my_rocksdb/rubble; python3 plot-iostat.py iostat-${suffix}.out 10"

sudo killall java
