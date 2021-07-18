#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: bash rsync.sh shard_num ip_0 ... ip_N"
    exit
fi

shard_num=$1
shift
path=`pwd`

for ip in $*
do
    for j in $(seq 1 $shard_num)
    do
        rsync -aP $path/ $USER@$ip:~/YCSB-$j
        ssh $USER@$ip "cd ~/YCSB-$j; bash build.sh"
    done
done
