#!/bin/bash

set -x

if [ $# -lt 5 ]; then
    echo "Usage: bash eval.sh replicator_port mode(run or load) workload ip_0 ... ip_N"
    exit
fi

port=$1
mode=$2
workload=$3
shift 3
shard_num=$#

# kill zumbie replicator, heads, and tails
bash kill.sh $*
sleep 5

# start nodes from tail to head
ip=($*)
replicator_args=''
sleep_ms=100
# cp the dataset in parallel
for i in $(seq 1 $shard_num)
do
    for j in $(seq 1 $#)
    do
        ssh ${USER}@${ip[$j-1]} "cd /mnt/sdb/; rm -rf rocksdb-${i} > /dev/null 2>&1; nohup cp -r rocksdb-${i}-backup rocksdb-${i} > /dev/null & echo \$! > rocksdb-${i}-pid.txt"
    done
done
for i in $(seq 1 $shard_num)
do
    cur_port=`expr 8980 + $i`
    pre_port=`expr 8979 + $i`
    # start nodes in background
    for j in $(seq 1 $#)
    do
        cur_ip=${ip[$j-1]}
        pre_ip=${ip[$j-2]}
        case $i in
            1)
            replicator_args='-p tail'${j}'='${cur_ip}:${cur_port}' '$replicator_args
            ssh ${USER}@${cur_ip} "cd YCSB-${i}; nohup bash node.sh /mnt/sdb/rocksdb-${i} ${cur_port} tail null $sleep_ms > nohup.out 2>&1 &"
            ;;

            $shard_num)
            chain=`expr $j - $shard_num + 1`
            if [ $chain -lt 1 ]
            then
                chain=`expr $chain + $shard_num`
            fi
            replicator_args='-p head'${chain}'='${cur_ip}:${cur_port}' '$replicator_args
            ssh ${USER}@${cur_ip} "cd YCSB-${i}; nohup bash node.sh /mnt/sdb/rocksdb-${i} ${cur_port} head ${pre_ip}:${pre_port} $sleep_ms > nohup.out 2>&1 &"
            ;;

            *)
            ssh ${USER}@${cur_ip} "cd YCSB-${i}; nohup bash node.sh /mnt/sdb/rocksdb-${i} ${cur_port} mid ${pre_ip}:${pre_port} $sleep_ms > nohup.out 2>&1 &"
            ;;
        esac
    done
    # wait for current nodes to be ready, then we start the next round of nodes
    for j in $(seq 1 $#)
    do
        cur_ip=${ip[$j-1]}
        ssh ${USER}@${cur_ip} "cd YCSB-${i}; until grep 'Server started' nohup.out > /dev/null; do sleep 1; done"
    done
done

echo $replicator_args
# start the replicator
./bin/ycsb.sh replicator rocksdb -s -P workloads/workloada -p port=$port -p shard=$shard_num $replicator_args > replicator.out 2>&1 &

# start ycsb
bash $mode.sh $workload localhost:$port $shard_num $sleep_ms > ycsb.out 2>&1
grep Throughput ycsb.out

# kill replicator, heads, and tails
bash kill.sh $*
sleep 5