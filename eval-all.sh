#!/bin/bash

if [ $# -lt 5 ]; then
    echo "Usage: bash eval.sh replicator_port ip_0 ip_1 head_port tail_port"
    exit
fi

for w in {a,b,c,d,g}
    do
        echo workload$w
        mkdir -p logs/$w/with-compaction
        for i in {1..5}
            do 
                echo $i
                bash eval.sh $1 $2 $3 $4 $5 run $w
                mv replicator.out logs/$w/with-compaction/replicator-$i.out
                mv ycsb.out logs/$w/with-compaction/ycsb-$i.out
                sleep 5
            done
            
        bash change-jar.sh $2 $3 no-compaction.jar

        mkdir -p logs/$w/no-compaction
        for i in {1..5}
            do 
                echo $i
                bash eval.sh $1 $2 $3 $4 $5 run $w
                mv replicator.out logs/$w/no-compaction/replicator-$i.out
                mv ycsb.out logs/$w/no-compaction/ycsb-$i.out
                sleep 5
            done

        bash change-jar.sh $2 $3 with-compaction.jar
    done