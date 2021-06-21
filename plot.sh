#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: bash plot.sh dir ip0 ... ipN"
    exit
fi

dir=$1
shift
shard_num=$#
mkdir -p $dir

for ip in $*
do
    scp ${USER}@${ip}:~/iostat.out $dir/iostat-${ip}.out
    for idx in $( seq 1 $shard_num )
    do
        scp ${USER}@${ip}:~/YCSB-${idx}/nohup.out $dir/node-${ip}-${idx}.out
    done
done

cp iostat.out ycsb.out $dir

# for file in iostat*.out
# do
#     echo $file
#     python $OLDPWD/plot-hardware.py $file
# done