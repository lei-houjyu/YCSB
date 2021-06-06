#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: bash update-nodes.sh jar folder ip_0 ... ip_N"
    exit
fi

jar=$1
folder=$2
shift 2
for ip in $*
do
    ssh ${USER}@$ip "cd $folder; cp $jar rocksdb/target/dependency/rocksdbjni-6.14.0.jar"
done