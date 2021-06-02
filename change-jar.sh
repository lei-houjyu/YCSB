#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: bash update-nodes.sh ip_0 ip_1 jar_name"
    exit
fi

sudo killall java
ssh ${USER}@$1 "cp $3 YCSB-tail/rocksdb/target/dependency/rocksdbjni-6.14.0.jar"
ssh ${USER}@$2 "cp $3 YCSB-tail/rocksdb/target/dependency/rocksdbjni-6.14.0.jar"